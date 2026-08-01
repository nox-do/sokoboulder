import Testing
@testable import GameCore
@testable import MacGameApp

@Suite("Sokoban level catalog")
@MainActor
struct SokobanLevelCatalogTests {
    /// Locked SHA-256 hex values for the built-in tutorial ASCII maps.
    private static let hash001 =
        "d64cfb9a722ee1300ebfd1147186324bf7a38f6246f0e9b7356b3dbd02aef4e9"
    private static let hash002 =
        "ec50f040ccf48c6837de76e23fc51e4980a87f08777cdc2473782ee5ac162227"
    private static let hash003 =
        "53f1d540013c703e60145fbf6764ecbf0f13fdec136e579f1ced1ef1cf1b9e44"

    @Test("catalog exposes three stable tutorial IDs with hashes")
    func threeStableTutorials() throws {
        #expect(SokobanLevelCatalog.tutorial.count == 3)
        #expect(SokobanLevelCatalog.tutorial.map(\.id) == [
            "sokoban.tutorial.001",
            "sokoban.tutorial.002",
            "sokoban.tutorial.003",
        ])

        for descriptor in SokobanLevelCatalog.tutorial {
            #expect(!descriptor.title.isEmpty)
            #expect(!descriptor.tutorialHintID.isEmpty)
            #expect(descriptor.contentHash.count == 64)
            #expect(try SokobanContentHasher.sha256Hex(ascii: descriptor.ascii) == descriptor.contentHash)
            _ = try descriptor.makeLevel()
        }
    }

    @Test("recorded golden hashes stay stable")
    func recordedGoldenHashes() {
        #expect(SokobanLevelCatalog.tutorial[0].contentHash == Self.hash001)
        #expect(SokobanLevelCatalog.tutorial[1].contentHash == Self.hash002)
        #expect(SokobanLevelCatalog.tutorial[2].contentHash == Self.hash003)
    }

    @Test("golden solutions complete every tutorial level")
    func goldenSolutionsComplete() throws {
        let rules = SokobanRules()
        let solutions = [
            SokobanTutorialSolutions.level001,
            SokobanTutorialSolutions.level002,
            SokobanTutorialSolutions.level003,
        ]

        for (descriptor, moves) in zip(SokobanLevelCatalog.tutorial, solutions) {
            var state = try rules.start(level: try descriptor.makeLevel())
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
    func lookupAndSuccessor() {
        #expect(SokobanLevelCatalog.descriptor(id: "missing") == nil)
        #expect(SokobanLevelCatalog.first.id == "sokoban.tutorial.001")
        #expect(
            SokobanLevelCatalog.descriptor(after: "sokoban.tutorial.001")?.id
                == "sokoban.tutorial.002"
        )
        #expect(SokobanLevelCatalog.descriptor(after: "sokoban.tutorial.003") == nil)
    }

    @Test("play controller boots the first catalog level")
    func playControllerUsesCatalog() {
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend())
        )
        #expect(controller.levelTitle == "Der erste Schub")
        #expect(controller.session != nil)
    }
}
