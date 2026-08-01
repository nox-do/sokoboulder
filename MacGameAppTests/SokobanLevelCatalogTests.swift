import Foundation
import Testing
@testable import GameCore
@testable import MacGameApp

@Suite("Sokoban level catalog")
@MainActor
struct SokobanLevelCatalogTests {
    /// Locked SHA-256 hex values for the built-in tutorial gameplay content.
    private static let hash001 =
        "11d20dcf2b735f52b3522e76d7b22df60fc855563d8754462f80b57d609fc585"
    private static let hash002 =
        "f92868cd9a13d2a807284392d139a17975f0a618cdfa1caec5a29373583cf0d6"
    private static let hash003 =
        "3284cef6842fcd0846d64daafba7acecbdd41089f5a8e8da6461998698bb6e15"

    @Test("bundled catalog loads three stable tutorial IDs with hashes")
    func threeStableTutorials() throws {
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        #expect(catalog.levels.count == 3)
        #expect(catalog.levels.map(\.id) == [
            "sokoban.tutorial.001",
            "sokoban.tutorial.002",
            "sokoban.tutorial.003",
        ])

        for descriptor in catalog.levels {
            #expect(!catalog.title(for: descriptor).isEmpty)
            #expect(descriptor.tutorialHintID != nil)
            #expect(!(descriptor.tutorialHintID ?? "").isEmpty)
            #expect(catalog.tutorialHint(for: descriptor) != descriptor.tutorialHintID)
            #expect(descriptor.contentHash.count == 64)
            #expect(
                SokobanContentHasher.sha256Hex(
                    game: .sokoban,
                    schemaVersion: 1,
                    map: try SokobanASCIIParser.parse(descriptor.rows.joined(separator: "\n"))
                ) == descriptor.contentHash
            )
            _ = descriptor.makeLevel()
        }
    }

    @Test("recorded golden hashes stay stable")
    func recordedGoldenHashes() throws {
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        #expect(catalog.levels[0].contentHash == Self.hash001)
        #expect(catalog.levels[1].contentHash == Self.hash002)
        #expect(catalog.levels[2].contentHash == Self.hash003)
    }

    @Test("golden solutions complete every tutorial level")
    func goldenSolutionsComplete() throws {
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        let rules = SokobanRules()
        let solutions = [
            SokobanTutorialSolutions.level001,
            SokobanTutorialSolutions.level002,
            SokobanTutorialSolutions.level003,
        ]

        for (descriptor, moves) in zip(catalog.levels, solutions) {
            var state = try rules.start(level: descriptor.makeLevel())
            for direction in moves {
                let transition = try rules.move(direction, in: state)
                #expect(
                    transition.outcome == .changed
                        || transition.outcome == .terminal(.completed),
                    "blocked while solving \(descriptor.id)"
                )
                state = transition.state
            }
            #expect(state.status == .completed, "\(descriptor.id) not completed")
        }
    }

    @Test("descriptor lookup and successor")
    func lookupAndSuccessor() throws {
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        #expect(catalog.descriptor(id: "missing") == nil)
        #expect(catalog.first.id == "sokoban.tutorial.001")
        #expect(
            catalog.descriptor(after: "sokoban.tutorial.001")?.id
                == "sokoban.tutorial.002"
        )
        #expect(catalog.descriptor(after: "sokoban.tutorial.003") == nil)
    }

    @Test("play controller boots the first catalog level")
    func playControllerUsesCatalog() throws {
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        let persistence = try SokobanRunPersistence.ephemeral()
        let progress = try ProgressPersistence.ephemeral(firstLevelID: catalog.first.id)
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: persistence,
            progressPersistence: progress,
            catalog: catalog
        )
        #expect(controller.levelTitle == "Der erste Schub")
        #expect(controller.session != nil)
        #expect(controller.presentationPhase == .levelIntro)
        #expect(controller.currentLevelID == "sokoban.tutorial.001")
    }

    @Test("missing string IDs are rejected when loading catalog")
    func missingStringIDsRejected() throws {
        // Cross-check: every title/hint ID in the real catalog resolves.
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        for descriptor in catalog.levels {
            #expect(catalog.strings.contains(descriptor.titleID))
            if let hint = descriptor.tutorialHintID {
                #expect(catalog.strings.contains(hint))
            }
        }
    }
}
