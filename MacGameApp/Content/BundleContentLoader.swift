import Foundation
import GameCore

/// Why bundled content cannot be used.
enum ContentLoadError: Error, Equatable, Sendable {
    case missingResource(path: String)
    case unreadable(path: String, detail: String)
    case manifestUnsupportedSchema(Int)
    case expectedExactlyOneCampaign(found: Int)
    case emptyCampaignID
    case emptyCampaignLevels(campaignID: String)
    case emptyLevelPath(campaignID: String)
    case duplicateLevelPath(String)
    case duplicateLevelID(String)
    case missingStringID(String)
    case emptyStringValue(String)
    case manifestUnknownKeys([String])
    case manifestMissingKeys([String])
    case level(SokobanLevelJSONError)
    case caveLevel(CaveLevelJSONError)
}

/// Loaded Sokoban campaign content: ordered descriptors + string table.
struct SokobanContentCatalog: Equatable, Sendable {
    let campaignID: String
    let levels: [SokobanLevelDescriptor]
    let strings: ContentStringTable
    let defaultThemeID: String?
    let defaultAudioThemeID: String?

    var first: SokobanLevelDescriptor {
        levels[0]
    }

    func descriptor(id: String) -> SokobanLevelDescriptor? {
        levels.first { $0.id == id }
    }

    func index(of id: String) -> Int? {
        levels.firstIndex { $0.id == id }
    }

    func descriptor(after id: String) -> SokobanLevelDescriptor? {
        guard let index = index(of: id), index + 1 < levels.count else {
            return nil
        }
        return levels[index + 1]
    }

    func title(for descriptor: SokobanLevelDescriptor) -> String {
        strings.text(descriptor.titleID)
    }

    func tutorialHint(for descriptor: SokobanLevelDescriptor) -> String {
        guard let hintID = descriptor.tutorialHintID else { return "" }
        return strings.text(hintID)
    }
}

/// Loaded Cave campaign content: ordered descriptors + string table.
struct CaveContentCatalog: Equatable, Sendable {
    let campaignID: String
    let levels: [CaveLevelDescriptor]
    let strings: ContentStringTable

    var first: CaveLevelDescriptor {
        levels[0]
    }

    /// Levels with a tutorial hint — always unlocked in campaign progress.
    var tutorialLevelIDs: [String] {
        levels.compactMap { descriptor in
            guard let hintID = descriptor.tutorialHintID, !hintID.isEmpty else { return nil }
            return descriptor.id
        }
    }

    func descriptor(id: String) -> CaveLevelDescriptor? {
        levels.first { $0.id == id }
    }

    func index(of id: String) -> Int? {
        levels.firstIndex { $0.id == id }
    }

    func descriptor(after id: String) -> CaveLevelDescriptor? {
        guard let index = index(of: id), index + 1 < levels.count else {
            return nil
        }
        return levels[index + 1]
    }

    func title(for descriptor: CaveLevelDescriptor) -> String {
        strings.text(descriptor.titleID)
    }

    func tutorialHint(for descriptor: CaveLevelDescriptor) -> String {
        guard let hintID = descriptor.tutorialHintID else { return "" }
        return strings.text(hintID)
    }
}

/// Loads manifest, level JSON, and content strings from a ``ContentResourceProvider``.
enum BundleContentLoader {
    /// Paths are relative to the app bundle Resources root (folder structure preserved).
    static let manifestPath = "Levels/manifest.json"
    static let caveManifestPath = "Levels/cave.manifest.json"
    static let contentStringsPath = "Localization/ContentStrings.de.json"

    /// Loads and cross-validates the bundled Sokoban campaign from an app bundle.
    static func loadSokobanCatalog(from bundle: Bundle) throws -> SokobanContentCatalog {
        try loadSokobanCatalog(from: BundleContentResources(bundle: bundle))
    }

    /// Loads and cross-validates the bundled Cave demo campaign from an app bundle.
    static func loadCaveCatalog(from bundle: Bundle) throws -> CaveContentCatalog {
        try loadCaveCatalog(from: BundleContentResources(bundle: bundle))
    }

    /// Loads and cross-validates content via an injectable resource provider.
    static func loadSokobanCatalog(from resources: any ContentResourceProvider) throws -> SokobanContentCatalog {
        let manifest = try loadManifest(at: manifestPath, from: resources)
        guard manifest.schemaVersion == ContentManifestV1.currentSchemaVersion else {
            throw ContentLoadError.manifestUnsupportedSchema(manifest.schemaVersion)
        }
        guard manifest.campaigns.count == 1 else {
            throw ContentLoadError.expectedExactlyOneCampaign(found: manifest.campaigns.count)
        }
        let campaign = manifest.campaigns[0]
        guard !campaign.id.isEmpty else {
            throw ContentLoadError.emptyCampaignID
        }

        let strings = try loadContentStrings(from: resources)
        var levels: [SokobanLevelDescriptor] = []
        var seenPaths = Set<String>()
        var seenIDs = Set<String>()

        for path in campaign.levels {
            guard !path.isEmpty else {
                throw ContentLoadError.emptyLevelPath(campaignID: campaign.id)
            }
            guard seenPaths.insert(path).inserted else {
                throw ContentLoadError.duplicateLevelPath(path)
            }

            let data = try resources.data(at: path)
            let decoded: DecodedSokobanLevelFile
            do {
                decoded = try SokobanLevelJSONCodec.decode(data)
            } catch let error as SokobanLevelJSONError {
                throw ContentLoadError.level(error)
            } catch let error as ContentLoadError {
                throw error
            } catch {
                throw ContentLoadError.unreadable(path: path, detail: String(describing: error))
            }

            guard seenIDs.insert(decoded.file.id).inserted else {
                throw ContentLoadError.duplicateLevelID(decoded.file.id)
            }

            try requireNonEmptyString(decoded.file.titleID, in: strings)
            if let goalTextID = decoded.file.goalTextID {
                try requireNonEmptyString(goalTextID, in: strings)
            }
            if let tutorialHintID = decoded.file.tutorialHintID {
                try requireNonEmptyString(tutorialHintID, in: strings)
            }

            levels.append(SokobanLevelDescriptor(decoded: decoded))
        }

        guard !levels.isEmpty else {
            throw ContentLoadError.emptyCampaignLevels(campaignID: campaign.id)
        }

        return SokobanContentCatalog(
            campaignID: campaign.id,
            levels: levels,
            strings: strings,
            defaultThemeID: manifest.defaultThemeID,
            defaultAudioThemeID: manifest.defaultAudioThemeID
        )
    }

    /// Loads and cross-validates the Cave demo campaign via an injectable provider.
    static func loadCaveCatalog(from resources: any ContentResourceProvider) throws -> CaveContentCatalog {
        let manifest = try loadManifest(at: caveManifestPath, from: resources)
        guard manifest.schemaVersion == ContentManifestV1.currentSchemaVersion else {
            throw ContentLoadError.manifestUnsupportedSchema(manifest.schemaVersion)
        }
        guard manifest.campaigns.count == 1 else {
            throw ContentLoadError.expectedExactlyOneCampaign(found: manifest.campaigns.count)
        }
        let campaign = manifest.campaigns[0]
        guard !campaign.id.isEmpty else {
            throw ContentLoadError.emptyCampaignID
        }

        let strings = try loadContentStrings(from: resources)
        var levels: [CaveLevelDescriptor] = []
        var seenPaths = Set<String>()
        var seenIDs = Set<String>()

        for path in campaign.levels {
            guard !path.isEmpty else {
                throw ContentLoadError.emptyLevelPath(campaignID: campaign.id)
            }
            guard seenPaths.insert(path).inserted else {
                throw ContentLoadError.duplicateLevelPath(path)
            }

            let data = try resources.data(at: path)
            let decoded: DecodedCaveLevelFile
            do {
                decoded = try CaveLevelJSONCodec.decode(data)
            } catch let error as CaveLevelJSONError {
                throw ContentLoadError.caveLevel(error)
            } catch let error as ContentLoadError {
                throw error
            } catch {
                throw ContentLoadError.unreadable(path: path, detail: String(describing: error))
            }

            guard seenIDs.insert(decoded.file.id).inserted else {
                throw ContentLoadError.duplicateLevelID(decoded.file.id)
            }

            try requireNonEmptyString(decoded.file.titleID, in: strings)
            if let tutorialHintID = decoded.file.tutorialHintID {
                try requireNonEmptyString(tutorialHintID, in: strings)
            }

            levels.append(CaveLevelDescriptor(decoded: decoded))
        }

        guard !levels.isEmpty else {
            throw ContentLoadError.emptyCampaignLevels(campaignID: campaign.id)
        }

        return CaveContentCatalog(
            campaignID: campaign.id,
            levels: levels,
            strings: strings
        )
    }

    private static func requireNonEmptyString(_ id: String, in table: ContentStringTable) throws {
        guard table.contains(id) else {
            throw ContentLoadError.missingStringID(id)
        }
        guard !table.text(id).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContentLoadError.emptyStringValue(id)
        }
    }

    private static func loadManifest(
        at path: String,
        from resources: any ContentResourceProvider
    ) throws -> ContentManifestV1 {
        let data = try resources.data(at: path)
        do {
            try StrictManifestJSON.validateKeys(data)
            return try JSONDecoder().decode(ContentManifestV1.self, from: data)
        } catch let error as StrictManifestJSON.Error {
            switch error {
            case .notAnObject:
                throw ContentLoadError.unreadable(path: path, detail: "Manifest must be a JSON object")
            case .unknownKeys(let keys):
                throw ContentLoadError.manifestUnknownKeys(keys)
            case .missingKeys(let keys):
                throw ContentLoadError.manifestMissingKeys(keys)
            }
        } catch let error as ContentLoadError {
            throw error
        } catch {
            throw ContentLoadError.unreadable(path: path, detail: String(describing: error))
        }
    }

    private static func loadContentStrings(from resources: any ContentResourceProvider) throws -> ContentStringTable {
        let data = try resources.data(at: contentStringsPath)
        do {
            return try ContentStringTable.decodeJSON(data)
        } catch let error as ContentLoadError {
            throw error
        } catch {
            throw ContentLoadError.unreadable(path: contentStringsPath, detail: String(describing: error))
        }
    }
}

/// Strict key checks for ContentManifestV1 JSON.
enum StrictManifestJSON {
    enum Error: Swift.Error, Equatable, Sendable {
        case notAnObject
        case unknownKeys([String])
        case missingKeys([String])
    }

    static func validateKeys(_ data: Data) throws {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw Error.notAnObject
        }
        guard let dict = object as? [String: Any] else {
            throw Error.notAnObject
        }

        let allowed: Set<String> = [
            "schemaVersion",
            "campaigns",
            "defaultThemeID",
            "defaultAudioThemeID",
        ]
        let required: Set<String> = [
            "schemaVersion",
            "campaigns",
        ]

        let keys = Set(dict.keys)
        let unknown = keys.subtracting(allowed).sorted()
        guard unknown.isEmpty else {
            throw Error.unknownKeys(unknown)
        }
        let missing = required.subtracting(keys).sorted()
        guard missing.isEmpty else {
            throw Error.missingKeys(missing)
        }
    }
}
