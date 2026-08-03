import AVFoundation
import Foundation
import Testing

@testable import MacGameApp

@Suite("Phase 3.5 audio theme contract")
struct Phase35AudioThemeTests {
    private static let allCueKeysJSON = """
        "movementStep": null,
        "movementBlocked": null,
        "objectPushed": null,
        "objectLanded": null,
        "collectiblePickedUp": null,
        "objectiveCompleted": null,
        "exitOpened": null,
        "playerDied": null,
        "timeExpired": null,
        "goalLeft": null
        """

    @Test("bundled audio catalog loads sokoban and cave themes")
    func loadsBundledCatalog() throws {
        let catalog = try AudioThemeCatalogLoader.loadStrict(
            from: BundleContentResources(bundle: Bundle(for: SokobanPlayController.self))
        )
        #expect(catalog.defaultThemeID == AudioTheme.sokobanID)
        #expect(catalog.theme(id: AudioTheme.sokobanID)?.musicPlayingPath
            == "Audio/Music/sokoban-puzzling.mp3")
        #expect(catalog.theme(id: AudioTheme.caveID)?.musicPlayingPath
            == "Audio/Music/cave-wonder.mp3")
        #expect(catalog.resolvedTheme(for: .sokoban).id == AudioTheme.sokobanID)
        #expect(catalog.resolvedTheme(for: .cave).id == AudioTheme.caveID)
    }

    @Test("bundled themes map configured cues to decodable wav assets")
    func bundledCuePathsAreDecodable() throws {
        let resources = BundleContentResources(bundle: Bundle(for: SokobanPlayController.self))
        let catalog = try AudioThemeCatalogLoader.loadStrict(from: resources)
        for themeID in [AudioTheme.sokobanID, AudioTheme.caveID] {
            let theme = try #require(catalog.theme(id: themeID))
            for cue in AudioCue.allCases {
                guard let path = theme.resourcePath(for: cue) else { continue }
                let url = try resources.url(at: path)
                #expect(url.pathExtension == "wav")
                #expect((try? AVAudioFile(forReading: url)) != nil)
            }
        }
        let cave = try #require(catalog.theme(id: AudioTheme.caveID))
        #expect(cave.resourcePath(for: .exitOpened) != nil)
        #expect(cave.resourcePath(for: .playerDied) != nil)
        #expect(cave.resourcePath(for: .goalLeft) == nil)
    }

    @Test("unknown keys are rejected by audio theme codec")
    func rejectsUnknownKeys() throws {
        let json = """
            {
              "schemaVersion": 1,
              "id": "audio.sokoban",
              "game": "sokoban",
              "music": { "playing": null },
              "cues": {
                \(Self.allCueKeysJSON)
              },
              "extra": true
            }
            """
        #expect(throws: AudioThemeDecodeError.unknownKeys(["extra"])) {
            _ = try AudioThemeFileCodec.decodeTheme(Data(json.utf8))
        }
    }

    @Test("missing cue keys are rejected")
    func rejectsMissingCueKeys() throws {
        let json = """
            {
              "schemaVersion": 1,
              "id": "audio.sokoban",
              "game": "sokoban",
              "music": { "playing": null },
              "cues": {
                "movementStep": null
              }
            }
            """
        #expect(throws: AudioThemeDecodeError.self) {
            _ = try AudioThemeFileCodec.decodeTheme(Data(json.utf8))
        }
    }

    @Test("catalog falls back to built-ins when manifest is missing")
    func catalogFallback() {
        let empty = DirectoryContentResources(root: FileManager.default.temporaryDirectory)
        let catalog = AudioThemeCatalogLoader.load(from: empty)
        #expect(catalog.theme(id: AudioTheme.sokobanID)?.id == AudioTheme.sokobanID)
        #expect(catalog.theme(id: AudioTheme.caveID)?.id == AudioTheme.caveID)
        #expect(catalog.resolvedTheme(for: .cave).musicPlayingPath
            == "Audio/Music/cave-wonder.mp3")
    }

    @Test("theme may reference missing cue files without failing decode")
    func missingCuePathStillDecodes() throws {
        let json = """
            {
              "schemaVersion": 1,
              "id": "audio.sokoban",
              "game": "sokoban",
              "music": { "playing": "Audio/Music/does-not-exist.mp3" },
              "cues": {
                "movementStep": "Audio/Effects/missing.wav",
                "movementBlocked": null,
                "objectPushed": null,
                "objectLanded": null,
                "collectiblePickedUp": null,
                "objectiveCompleted": null,
                "exitOpened": null,
                "playerDied": null,
                "timeExpired": null,
                "goalLeft": null
              }
            }
            """
        let theme = try AudioThemeFileCodec.decodeTheme(Data(json.utf8))
        #expect(theme.musicPlayingPath == "Audio/Music/does-not-exist.mp3")
        #expect(theme.resourcePath(for: .movementStep) == "Audio/Effects/missing.wav")
        #expect(theme.resourcePath(for: .movementBlocked) == nil)
    }
}

@Suite("Phase 3.5 audio theme director wiring")
@MainActor
struct Phase35AudioThemeDirectorTests {
    @Test("director switches theme when game mode changes")
    func switchesThemeByGame() {
        let spy = SpyAudioPlaybackBackend()
        let catalog = AudioThemeCatalog(
            themes: BuiltInAudioThemes.allFallbacks(),
            defaultThemeID: AudioTheme.sokobanID
        )
        let director = AudioDirector(backend: spy, catalog: catalog)
        #expect(director.activeTheme.id == AudioTheme.sokobanID)
        spy.resetCalls()

        director.apply(
            AudioUpdate(
                targetRevision: 1,
                context: AudioContext(game: .cave, levelID: "cave.demo", status: .playing),
                events: [],
                delivery: .synchronize
            )
        )
        #expect(director.activeTheme.id == AudioTheme.caveID)
        #expect(spy.calls.contains(.applyTheme(AudioTheme.caveID)))
        #expect(spy.musicStates == [.themeLoop])
    }
}
