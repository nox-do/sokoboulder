import Foundation
import Testing
@testable import GameCore
@testable import MacGameApp

@Suite("Bundle content loader")
struct BundleContentLoaderTests {
    @Test("loads and validates the shipped manifest and levels from the app bundle")
    func loadsShippedContent() throws {
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        #expect(catalog.campaignID == "campaign.sokoban.main")
        #expect(catalog.levels.count == 93)
        #expect(catalog.defaultThemeID == nil)
        #expect(catalog.defaultAudioThemeID == nil)

        // Paths must resolve via preserved folder structure, not basename fallback.
        let resources = BundleContentResources(bundle: Bundle(for: SokobanPlayController.self))
        _ = try resources.data(at: "Levels/manifest.json")
        _ = try resources.data(at: "Levels/sokoban.tutorial.001.json")
        _ = try resources.data(at: "Localization/ContentStrings.de.json")
        #expect(throws: ContentLoadError.missingResource(path: "manifest.json")) {
            _ = try resources.data(at: "manifest.json")
        }
    }

    @Test("rejects duplicate level IDs via the loader")
    func rejectsDuplicateLevelIDs() throws {
        let root = try makeTempContentRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let level = validLevelJSON(id: "dup.id", titleID: "t1")
        try write(level, to: root, path: "Levels/a.json")
        try write(level, to: root, path: "Levels/b.json")
        try write(
            """
            {
              "schemaVersion": 1,
              "campaigns": [{
                "id": "c",
                "levels": [
                  "Levels/a.json",
                  "Levels/b.json"
                ]
              }]
            }
            """,
            to: root,
            path: BundleContentLoader.manifestPath
        )
        try write(#"{"t1":"Title"}"#, to: root, path: BundleContentLoader.contentStringsPath)

        #expect(throws: ContentLoadError.duplicateLevelID("dup.id")) {
            _ = try BundleContentLoader.loadSokobanCatalog(from: DirectoryContentResources(root: root))
        }
    }

    @Test("rejects missing string IDs via the loader")
    func rejectsMissingStringIDs() throws {
        let root = try makeTempContentRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try write(
            validLevelJSON(id: "x", titleID: "missing.title"),
            to: root,
            path: "Levels/x.json"
        )
        try write(
            """
            {
              "schemaVersion": 1,
              "campaigns": [{
                "id": "c",
                "levels": ["Levels/x.json"]
              }]
            }
            """,
            to: root,
            path: BundleContentLoader.manifestPath
        )
        try write(#"{}"#, to: root, path: BundleContentLoader.contentStringsPath)

        #expect(throws: ContentLoadError.missingStringID("missing.title")) {
            _ = try BundleContentLoader.loadSokobanCatalog(from: DirectoryContentResources(root: root))
        }
    }

    @Test("rejects empty string values via the loader")
    func rejectsEmptyStringValues() throws {
        let root = try makeTempContentRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try write(
            validLevelJSON(id: "x", titleID: "empty.title"),
            to: root,
            path: "Levels/x.json"
        )
        try write(
            """
            {
              "schemaVersion": 1,
              "campaigns": [{
                "id": "c",
                "levels": ["Levels/x.json"]
              }]
            }
            """,
            to: root,
            path: BundleContentLoader.manifestPath
        )
        try write(#"{"empty.title":"   "}"#, to: root, path: BundleContentLoader.contentStringsPath)

        #expect(throws: ContentLoadError.emptyStringValue("empty.title")) {
            _ = try BundleContentLoader.loadSokobanCatalog(from: DirectoryContentResources(root: root))
        }
    }

    @Test("rejects manifests with more than one campaign")
    func rejectsMultipleCampaigns() throws {
        let root = try makeTempContentRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try write(
            validLevelJSON(id: "x", titleID: "t1"),
            to: root,
            path: "Levels/x.json"
        )
        try write(
            """
            {
              "schemaVersion": 1,
              "campaigns": [
                { "id": "a", "levels": ["Levels/x.json"] },
                { "id": "b", "levels": ["Levels/x.json"] }
              ]
            }
            """,
            to: root,
            path: BundleContentLoader.manifestPath
        )
        try write(#"{"t1":"Title"}"#, to: root, path: BundleContentLoader.contentStringsPath)

        #expect(throws: ContentLoadError.expectedExactlyOneCampaign(found: 2)) {
            _ = try BundleContentLoader.loadSokobanCatalog(from: DirectoryContentResources(root: root))
        }
    }

    @Test("rejects wrong level subdirectory without basename fallback")
    func rejectsWrongSubdirectory() throws {
        let root = try makeTempContentRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try write(
            validLevelJSON(id: "x", titleID: "t1"),
            to: root,
            path: "Levels/x.json"
        )
        try write(
            """
            {
              "schemaVersion": 1,
              "campaigns": [{
                "id": "c",
                "levels": ["Wrong/x.json"]
              }]
            }
            """,
            to: root,
            path: BundleContentLoader.manifestPath
        )
        try write(#"{"t1":"Title"}"#, to: root, path: BundleContentLoader.contentStringsPath)

        #expect(throws: ContentLoadError.missingResource(path: "Wrong/x.json")) {
            _ = try BundleContentLoader.loadSokobanCatalog(from: DirectoryContentResources(root: root))
        }
    }
}

private func makeTempContentRoot() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("SokobanContent-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func write(_ string: String, to root: URL, path: String) throws {
    let url = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data(string.utf8).write(to: url)
}

private func validLevelJSON(id: String, titleID: String) -> String {
    """
    {
      "schemaVersion": 1,
      "id": "\(id)",
      "game": "sokoban",
      "titleID": "\(titleID)",
      "width": 5,
      "height": 3,
      "rows": ["#####", "#@$.#", "#####"],
      "rules": {}
    }
    """
}
