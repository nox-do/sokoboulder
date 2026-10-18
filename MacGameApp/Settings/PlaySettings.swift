import AppKit
import Foundation

/// Owns settings actions and applies them to the board and audio.
@MainActor
final class PlaySettings {
    let store: AppSettingsStore
    let themeCatalog: ThemeCatalog
    let musicTrackCatalog: MusicTrackCatalog
    let reduceMotionProvider: ReduceMotionProvider
    private let scene: SokobanBoardScene
    private let audio: SettingsAudioBridge
    var onChange: (() -> Void)?

    var snapshot: AppSettingsSnapshot { store.snapshot }
    var visualTheme: VisualTheme {
        DevVisualThemeSwitch.forceVectorStandard
            ? BuiltInThemes.standard
            : themeCatalog.resolvedTheme(preferredID: store.themeID)
    }
    var presentation: SettingsPresentation {
        PresentationFactory.settings(
            snapshot: snapshot, musicTrackCatalog: musicTrackCatalog,
            themeCatalog: themeCatalog, selectedThemeID: visualTheme.id
        )
    }

    init(
        store: AppSettingsStore, scene: SokobanBoardScene, audioDirector: AudioDirector,
        reduceMotionSource: (any SystemReduceMotionSource)? = nil,
        themeCatalog: ThemeCatalog? = nil, musicTrackCatalog: MusicTrackCatalog? = nil
    ) {
        let resources = BundleContentResources(bundle: Bundle(for: PlaySettings.self))
        self.store = store
        self.scene = scene
        self.themeCatalog = themeCatalog ?? ThemeCatalogLoader.load(from: resources)
        self.musicTrackCatalog = musicTrackCatalog ?? MusicTrackCatalogLoader.load(from: resources)
        self.audio = SettingsAudioBridge(audioDirector: audioDirector, settingsStore: store)
        self.reduceMotionProvider = ReduceMotionProvider(
            settings: store, systemSource: reduceMotionSource ?? WorkspaceReduceMotionSource()
        )
        store.seedThemeIDFromCatalogIfUnset(self.themeCatalog.defaultThemeID)
        store.seedMusicTrackIDsFromCatalogIfUnset(
            sokobanDefault: self.musicTrackCatalog.defaultTrackID(for: .sokoban),
            caveDefault: self.musicTrackCatalog.defaultTrackID(for: .cave)
        )
        applyAudio()
        scene.apply(theme: visualTheme)
        scene.prefersReducedMotion = reduceMotionProvider.isReduceMotionEffective
        _ = store.addChangeHandler { [weak self] in
            guard let self else { return }
            self.applyAudio()
            self.scene.apply(theme: self.visualTheme)
            self.onChange?()
        }
        reduceMotionProvider.onEffectiveChange = { [weak scene] effective in
            scene?.prefersReducedMotion = effective
        }
        reduceMotionProvider.refresh()
    }

    func applyAudio() {
        audio.applyFromStore()
    }

    func updateReduceMotionEnabled(_ enabled: Bool) {
        store.reduceMotionEnabled = enabled
    }

    func updateThemeID(_ themeID: String) {
        store.themeID = themeID
    }

    func cycleTheme(by offset: Int) {
        let options = themeCatalog.selectableThemes
        guard !options.isEmpty else { return }
        let currentIndex = options.firstIndex { $0.id == visualTheme.id } ?? 0
        let count = options.count
        let nextIndex = ((currentIndex + offset) % count + count) % count
        store.themeID = options[nextIndex].id
    }

    func updateMusicTrackID(_ trackID: String, for game: AudioGameMode = .sokoban) {
        store.setMusicTrackID(trackID, for: game)
    }

    func cycleMusicTrack(for game: AudioGameMode = .sokoban, by offset: Int) {
        let options = musicTrackCatalog.selectableTracks(for: game)
        guard !options.isEmpty else { return }
        let currentID = store.musicTrackID(for: game)
        let currentIndex = options.firstIndex { $0.id == currentID } ?? 0
        let count = options.count
        let nextIndex = ((currentIndex + offset) % count + count) % count
        store.setMusicTrackID(options[nextIndex].id, for: game)
    }

    func updateMusicVolume(_ volume: Double) {
        store.musicVolume = volume
    }

    func updateEffectsVolume(_ volume: Double) {
        store.effectsVolume = volume
    }

    func updateMuted(_ muted: Bool) {
        store.isMuted = muted
    }
}
