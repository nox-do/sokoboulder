import AVFoundation
import Foundation
import Testing

@testable import MacGameApp

@Suite("Music track catalog")
struct MusicTrackCatalogTests {
    @Test("bundled catalog loads puzzling and prelude with credits")
    func loadsBundledCatalog() throws {
        let catalog = try MusicTrackCatalogLoader.loadStrict(
            from: BundleContentResources(bundle: Bundle(for: SokobanPlayController.self))
        )
        #expect(catalog.defaultTrackID == MusicTrack.puzzlingID)
        #expect(catalog.tracks(for: .sokoban).count == 2)

        let puzzling = try #require(catalog.track(id: MusicTrack.puzzlingID))
        #expect(puzzling.resourcePath == "Audio/Music/sokoban-puzzling.mp3")
        #expect(puzzling.credit.author == "Ruskerdax")
        #expect(puzzling.credit.attributionNotice == nil)
        #expect(puzzling.credit.license == "CC0 1.0")

        let prelude = try #require(catalog.track(id: MusicTrack.preludeID))
        #expect(prelude.resourcePath == "Audio/Music/sokoban-prelude.mp3")
        #expect(prelude.credit.author == "Alexandr Zhelanov")
        #expect(prelude.credit.license == "CC-BY 3.0")
        #expect(
            prelude.credit.attributionNotice
                == "Alexandr Zhelanov, https://soundcloud.com/alexandr-zhelanov"
        )
    }

    @Test("bundled prelude and puzzling music decode")
    func bundledTracksDecodable() throws {
        let resources = BundleContentResources(bundle: Bundle(for: SokobanPlayController.self))
        for path in [
            "Audio/Music/sokoban-puzzling.mp3",
            "Audio/Music/sokoban-prelude.mp3",
        ] {
            let url = try resources.url(at: path)
            #expect((try? AVAudioFile(forReading: url)) != nil)
        }
    }

    @Test("catalog falls back to built-ins when manifest is missing")
    func catalogFallback() {
        let empty = DirectoryContentResources(root: FileManager.default.temporaryDirectory)
        let catalog = MusicTrackCatalogLoader.load(from: empty)
        #expect(catalog.track(id: MusicTrack.puzzlingID)?.id == MusicTrack.puzzlingID)
        #expect(catalog.track(id: MusicTrack.preludeID)?.id == MusicTrack.preludeID)
    }

    @Test("unknown credit keys are rejected")
    func rejectsUnknownCreditKeys() throws {
        let json = """
            {
              "schemaVersion": 1,
              "defaultTrackID": "music.sokoban.puzzling",
              "tracks": [
                {
                  "id": "music.sokoban.puzzling",
                  "game": "sokoban",
                  "displayNameID": "music.sokoban.puzzling.name",
                  "resourcePath": "Audio/Music/sokoban-puzzling.mp3",
                  "credit": {
                    "title": "Puzzling",
                    "author": "Ruskerdax",
                    "sourceURL": "https://example.com",
                    "license": "CC0 1.0",
                    "extra": true
                  }
                }
              ]
            }
            """
        #expect(throws: MusicTrackDecodeError.self) {
            _ = try MusicTrackFileCodec.decodeManifest(Data(json.utf8))
        }
    }
}

@Suite("Music track settings wiring")
@MainActor
struct MusicTrackSettingsTests {
    @Test("settings music track selection updates director path")
    func settingsApplyMusicTrack() throws {
        let spy = SpyAudioPlaybackBackend()
        let director = AudioDirector(
            backend: spy,
            musicCatalog: MusicTrackCatalog(
                tracks: BuiltInMusicTracks.allFallbacks(),
                defaultTrackID: MusicTrack.puzzlingID
            )
        )
        let bundle = try TestPlayControllerFactory.make(
            audioDirector: director,
            markIntroDismissed: true
        )
        #expect(bundle.controller.settingsPresentation.musicTrackOptions.count == 2)
        #expect(bundle.settings.musicTrackID == MusicTrack.puzzlingID)
        #expect(spy.lastMusicPath == "Audio/Music/sokoban-puzzling.mp3")

        bundle.controller.updateMusicTrackID(MusicTrack.preludeID)
        #expect(bundle.settings.musicTrackID == MusicTrack.preludeID)
        #expect(director.selectedMusicTrackID == MusicTrack.preludeID)
        #expect(spy.lastMusicPath == "Audio/Music/sokoban-prelude.mp3")
        #expect(
            bundle.controller.settingsPresentation.selectedMusicAttributionNotice
                == "Alexandr Zhelanov, https://soundcloud.com/alexandr-zhelanov"
        )

        bundle.controller.cycleMusicTrack(by: 1)
        #expect(bundle.settings.musicTrackID == MusicTrack.puzzlingID)
    }

    @Test("music track preference persists")
    func musicTrackPersists() throws {
        let name = "\(AppSettingsStore.suitePrefix).music.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        let first = AppSettingsStore(defaults: defaults)
        first.musicTrackID = MusicTrack.preludeID

        let second = AppSettingsStore(defaults: defaults)
        #expect(second.musicTrackID == MusicTrack.preludeID)
        defaults.removePersistentDomain(forName: name)
    }
}
