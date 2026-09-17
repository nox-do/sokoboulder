import AVFoundation
import Foundation
import Testing

@testable import MacGameApp

@Suite("Music track catalog")
struct MusicTrackCatalogTests {
    @Test("bundled catalog loads sokoban and cave tracks with credits")
    func loadsBundledCatalog() throws {
        let catalog = try MusicTrackCatalogLoader.loadStrict(
            from: BundleContentResources(bundle: Bundle(for: SokobanPlayController.self))
        )
        #expect(catalog.defaultTrackID(for: .sokoban) == MusicTrack.puzzlingID)
        #expect(catalog.defaultTrackID(for: .cave) == MusicTrack.caveWonderID)
        #expect(catalog.tracks(for: .sokoban).count == 2)
        #expect(catalog.tracks(for: .cave).count == 2)

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

        let wonder = try #require(catalog.track(id: MusicTrack.caveWonderID))
        #expect(wonder.resourcePath == "Audio/Music/cave-wonder.mp3")
        #expect(wonder.credit.author == "tapatilorenzo")
        #expect(wonder.credit.license == "CC0 1.0")

        let tinkering = try #require(catalog.track(id: MusicTrack.caveTinkeringID))
        #expect(tinkering.resourcePath == "Audio/Music/cave-tinkering.mp3")
    }

    @Test("bundled music tracks decode")
    func bundledTracksDecodable() throws {
        let resources = BundleContentResources(bundle: Bundle(for: SokobanPlayController.self))
        for path in [
            "Audio/Music/sokoban-puzzling.mp3",
            "Audio/Music/sokoban-prelude.mp3",
            "Audio/Music/cave-wonder.mp3",
            "Audio/Music/cave-tinkering.mp3",
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
        #expect(catalog.track(id: MusicTrack.caveWonderID)?.id == MusicTrack.caveWonderID)
        #expect(catalog.defaultTrackID(for: .cave) == MusicTrack.caveWonderID)
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
                defaultTrackIDs: BuiltInMusicTracks.defaultTrackIDs()
            )
        )
        let bundle = try TestPlayControllerFactory.make(
            audioDirector: director,
            markIntroDismissed: true
        )
        #expect(bundle.controller.settingsPresentation.musicTrackGroups.count == 2)
        #expect(bundle.settings.sokobanMusicTrackID == MusicTrack.puzzlingID)
        #expect(bundle.settings.caveMusicTrackID == MusicTrack.caveWonderID)
        #expect(spy.lastMusicPath == "Audio/Music/sokoban-puzzling.mp3")

        bundle.controller.updateMusicTrackID(MusicTrack.preludeID, for: .sokoban)
        #expect(bundle.settings.sokobanMusicTrackID == MusicTrack.preludeID)
        #expect(director.selectedMusicTrackIDs[.sokoban] == MusicTrack.preludeID)
        #expect(spy.lastMusicPath == "Audio/Music/sokoban-prelude.mp3")
        let sokobanGroup = try #require(
            bundle.controller.settingsPresentation.musicTrackGroups.first { $0.game == .sokoban }
        )
        #expect(
            sokobanGroup.attributionNotice
                == "Alexandr Zhelanov, https://soundcloud.com/alexandr-zhelanov"
        )

        bundle.controller.cycleMusicTrack(for: .sokoban, by: 1)
        #expect(bundle.settings.sokobanMusicTrackID == MusicTrack.puzzlingID)

        bundle.controller.updateMusicTrackID(MusicTrack.caveTinkeringID, for: .cave)
        #expect(bundle.settings.caveMusicTrackID == MusicTrack.caveTinkeringID)
        #expect(director.selectedMusicTrackIDs[.cave] == MusicTrack.caveTinkeringID)
        // Active theme is still sokoban while playing Sokoban.
        #expect(spy.lastMusicPath == "Audio/Music/sokoban-puzzling.mp3")
    }

    @Test("pause then change sokoban track then resume keeps the new path")
    func pauseChangeSokobanTrackResume() throws {
        let spy = SpyAudioPlaybackBackend()
        let director = AudioDirector(
            backend: spy,
            musicCatalog: MusicTrackCatalog(
                tracks: BuiltInMusicTracks.allFallbacks(),
                defaultTrackIDs: BuiltInMusicTracks.defaultTrackIDs()
            )
        )
        let bundle = try TestPlayControllerFactory.make(
            audioDirector: director,
            markIntroDismissed: true
        )
        #expect(spy.lastMusicPath == "Audio/Music/sokoban-puzzling.mp3")

        bundle.controller.togglePause()
        bundle.controller.openSettingsFromPause()
        bundle.controller.updateMusicTrackID(MusicTrack.preludeID, for: .sokoban)
        #expect(bundle.settings.sokobanMusicTrackID == MusicTrack.preludeID)
        #expect(spy.lastMusicPath == "Audio/Music/sokoban-prelude.mp3")
        #expect(director.activeTheme.musicPlayingPath == "Audio/Music/sokoban-prelude.mp3")

        bundle.controller.dismissHelpOrSettings()
        spy.resetCalls()
        bundle.controller.resumeFromPauseOverlay()
        #expect(spy.musicStates == [.themeLoop])
        #expect(spy.lastMusicPath == "Audio/Music/sokoban-prelude.mp3")
        #expect(director.activeTheme.musicPlayingPath == "Audio/Music/sokoban-prelude.mp3")
    }

    @Test("real backend reloads looping music when the sokoban track changes")
    func proceduralBackendSwitchesSokobanTrack() throws {
        let resources = BundleContentResources(bundle: Bundle(for: SokobanPlayController.self))
        let backend = ProceduralAudioPlaybackBackend(resources: resources)
        let director = AudioDirector(
            backend: backend,
            musicCatalog: MusicTrackCatalogLoader.load(from: resources)
        )
        director.apply(
            AudioUpdate(
                targetRevision: 1,
                context: AudioContext(game: .sokoban, levelID: "t", status: .playing),
                events: [],
                delivery: .synchronize
            )
        )
        #expect(backend.loadedMusicPathForTesting == "Audio/Music/sokoban-puzzling.mp3")

        director.interrupt()
        director.applyMusicTrackID(MusicTrack.preludeID, for: .sokoban)
        #expect(backend.loadedMusicPathForTesting == "Audio/Music/sokoban-prelude.mp3")

        director.resumePlayback()
        #expect(backend.loadedMusicPathForTesting == "Audio/Music/sokoban-prelude.mp3")
    }

    @Test("music track preference persists per game")
    func musicTrackPersists() throws {
        let name = "\(AppSettingsStore.suitePrefix).music.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        let first = AppSettingsStore(defaults: defaults)
        first.sokobanMusicTrackID = MusicTrack.preludeID
        first.caveMusicTrackID = MusicTrack.caveTinkeringID

        let second = AppSettingsStore(defaults: defaults)
        #expect(second.sokobanMusicTrackID == MusicTrack.preludeID)
        #expect(second.caveMusicTrackID == MusicTrack.caveTinkeringID)
        defaults.removePersistentDomain(forName: name)
    }

    @Test("legacy musicTrackID migrates to sokoban preference")
    func legacyMusicTrackMigrates() throws {
        let name = "\(AppSettingsStore.suitePrefix).music.legacy.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        defaults.set(MusicTrack.preludeID, forKey: "settings.musicTrackID")

        let store = AppSettingsStore(defaults: defaults)
        #expect(store.sokobanMusicTrackID == MusicTrack.preludeID)
        store.sokobanMusicTrackID = MusicTrack.puzzlingID
        #expect(defaults.object(forKey: "settings.musicTrackID") == nil)
        defaults.removePersistentDomain(forName: name)
    }
}
