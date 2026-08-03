import Combine
import Foundation

/// Persisted presentation / audio preferences (Phase 3.3).
///
/// Audio-theme mapping and manifests arrive in Phase 3.5; this store is the
/// reusable settings surface those themes will read.
struct AppSettingsSnapshot: Equatable, Sendable {
    /// App-local reduce-motion preference (OR’d with the system setting).
    var reduceMotionEnabled: Bool
    /// Selected visual theme ID (`theme.dungeon`, `theme.kenney`, …).
    var themeID: String
    /// Selected Sokoban background track ID (`music.sokoban.puzzling`, …).
    var sokobanMusicTrackID: String
    /// Selected cave background track ID (`music.cave.wonder`, …).
    var caveMusicTrackID: String
    /// Music bus gain in `0...1`.
    var musicVolume: Double
    /// Effects / jingles bus gain in `0...1`.
    var effectsVolume: Double
    /// When true, music and effects are silent regardless of volume sliders.
    var isMuted: Bool

    static let `default` = AppSettingsSnapshot(
        reduceMotionEnabled: false,
        themeID: VisualTheme.dungeonID,
        sokobanMusicTrackID: MusicTrack.puzzlingID,
        caveMusicTrackID: MusicTrack.caveWonderID,
        musicVolume: 0.8,
        effectsVolume: 1.0,
        isMuted: false
    )

    func musicTrackID(for game: AudioGameMode) -> String {
        switch game {
        case .sokoban: sokobanMusicTrackID
        case .cave: caveMusicTrackID
        }
    }
}

/// Injectable UserDefaults-backed settings. Tests pass an isolated suite name.
@MainActor
final class AppSettingsStore: ObservableObject {
    static let suitePrefix = "com.sokoboulder.app.settings"

    private enum Key {
        static let reduceMotion = "settings.reduceMotion"
        static let themeID = "settings.themeID"
        /// Legacy single-track key; migrated into ``sokobanMusicTrackID``.
        static let legacyMusicTrackID = "settings.musicTrackID"
        static let sokobanMusicTrackID = "settings.sokobanMusicTrackID"
        static let caveMusicTrackID = "settings.caveMusicTrackID"
        static let musicVolume = "settings.musicVolume"
        static let effectsVolume = "settings.effectsVolume"
        static let isMuted = "settings.isMuted"
    }

    private let defaults: UserDefaults

    @Published private(set) var snapshot: AppSettingsSnapshot

    /// Synchronous observers (avoid relying on Combine delivery timing in tests).
    private var changeHandlers: [UUID: () -> Void] = [:]

    /// Production: standard `UserDefaults`. Tests: ephemeral suite via ``ephemeral()``.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.snapshot = Self.read(from: defaults)
    }

    /// Isolated suite so tests never touch the user’s real defaults.
    static func ephemeral(suiteName: String = UUID().uuidString) -> AppSettingsStore {
        let name = "\(suitePrefix).test.\(suiteName)"
        guard let defaults = UserDefaults(suiteName: name) else {
            preconditionFailure("Could not create UserDefaults suite \(name)")
        }
        defaults.removePersistentDomain(forName: name)
        return AppSettingsStore(defaults: defaults)
    }

    @discardableResult
    func addChangeHandler(_ handler: @escaping () -> Void) -> UUID {
        let id = UUID()
        changeHandlers[id] = handler
        return id
    }

    func removeChangeHandler(_ id: UUID) {
        changeHandlers.removeValue(forKey: id)
    }

    var reduceMotionEnabled: Bool {
        get { snapshot.reduceMotionEnabled }
        set { update { $0.reduceMotionEnabled = newValue } }
    }

    /// True when the user (or a previous seed write) has a persisted theme ID.
    var hasPersistedThemeID: Bool {
        defaults.object(forKey: Key.themeID) != nil
    }

    var hasPersistedSokobanMusicTrackID: Bool {
        defaults.object(forKey: Key.sokobanMusicTrackID) != nil
            || defaults.object(forKey: Key.legacyMusicTrackID) != nil
    }

    var hasPersistedCaveMusicTrackID: Bool {
        defaults.object(forKey: Key.caveMusicTrackID) != nil
    }

    /// Seeds the theme ID once from the theme catalog when no preference exists yet.
    func seedThemeIDFromCatalogIfUnset(_ catalogDefaultThemeID: String) {
        guard !hasPersistedThemeID else { return }
        let normalized = Self.normalizeThemeID(catalogDefaultThemeID)
        var next = snapshot
        next.themeID = normalized
        snapshot = next
        write(next)
        for handler in changeHandlers.values {
            handler()
        }
    }

    /// Seeds Sokoban / cave music track IDs once from the catalog when unset.
    func seedMusicTrackIDsFromCatalogIfUnset(
        sokobanDefault: String,
        caveDefault: String
    ) {
        var next = snapshot
        var changed = false
        if !hasPersistedSokobanMusicTrackID {
            next.sokobanMusicTrackID = Self.normalizeMusicTrackID(
                sokobanDefault,
                fallback: MusicTrack.puzzlingID
            )
            changed = true
        }
        if !hasPersistedCaveMusicTrackID {
            next.caveMusicTrackID = Self.normalizeMusicTrackID(
                caveDefault,
                fallback: MusicTrack.caveWonderID
            )
            changed = true
        }
        guard changed else { return }
        snapshot = next
        write(next)
        for handler in changeHandlers.values {
            handler()
        }
    }

    var themeID: String {
        get { snapshot.themeID }
        set { update { $0.themeID = Self.normalizeThemeID(newValue) } }
    }

    var sokobanMusicTrackID: String {
        get { snapshot.sokobanMusicTrackID }
        set {
            update {
                $0.sokobanMusicTrackID = Self.normalizeMusicTrackID(
                    newValue,
                    fallback: MusicTrack.puzzlingID
                )
            }
        }
    }

    var caveMusicTrackID: String {
        get { snapshot.caveMusicTrackID }
        set {
            update {
                $0.caveMusicTrackID = Self.normalizeMusicTrackID(
                    newValue,
                    fallback: MusicTrack.caveWonderID
                )
            }
        }
    }

    /// Compatibility alias used by older call sites / tests.
    var musicTrackID: String {
        get { sokobanMusicTrackID }
        set { sokobanMusicTrackID = newValue }
    }

    func musicTrackID(for game: AudioGameMode) -> String {
        snapshot.musicTrackID(for: game)
    }

    func setMusicTrackID(_ id: String, for game: AudioGameMode) {
        switch game {
        case .sokoban: sokobanMusicTrackID = id
        case .cave: caveMusicTrackID = id
        }
    }

    var musicVolume: Double {
        get { snapshot.musicVolume }
        set { update { $0.musicVolume = Self.clampVolume(newValue) } }
    }

    var effectsVolume: Double {
        get { snapshot.effectsVolume }
        set { update { $0.effectsVolume = Self.clampVolume(newValue) } }
    }

    var isMuted: Bool {
        get { snapshot.isMuted }
        set { update { $0.isMuted = newValue } }
    }

    func apply(_ next: AppSettingsSnapshot) {
        let clamped = AppSettingsSnapshot(
            reduceMotionEnabled: next.reduceMotionEnabled,
            themeID: Self.normalizeThemeID(next.themeID),
            sokobanMusicTrackID: Self.normalizeMusicTrackID(
                next.sokobanMusicTrackID,
                fallback: MusicTrack.puzzlingID
            ),
            caveMusicTrackID: Self.normalizeMusicTrackID(
                next.caveMusicTrackID,
                fallback: MusicTrack.caveWonderID
            ),
            musicVolume: Self.clampVolume(next.musicVolume),
            effectsVolume: Self.clampVolume(next.effectsVolume),
            isMuted: next.isMuted
        )
        guard clamped != snapshot else { return }
        snapshot = clamped
        write(clamped)
        for handler in changeHandlers.values {
            handler()
        }
    }

    static func clampVolume(_ value: Double) -> Double {
        AudioOutputSettings.clampVolume(value)
    }

    static func normalizeThemeID(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return VisualTheme.dungeonID }
        return trimmed
    }

    static func normalizeMusicTrackID(
        _ value: String,
        fallback: String
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return trimmed
    }

    // MARK: - Private

    private func update(_ mutate: (inout AppSettingsSnapshot) -> Void) {
        var next = snapshot
        mutate(&next)
        apply(next)
    }

    private func write(_ snapshot: AppSettingsSnapshot) {
        defaults.set(snapshot.reduceMotionEnabled, forKey: Key.reduceMotion)
        defaults.set(snapshot.themeID, forKey: Key.themeID)
        defaults.set(snapshot.sokobanMusicTrackID, forKey: Key.sokobanMusicTrackID)
        defaults.set(snapshot.caveMusicTrackID, forKey: Key.caveMusicTrackID)
        // Drop legacy key once migrated so we do not keep two sources of truth.
        defaults.removeObject(forKey: Key.legacyMusicTrackID)
        defaults.set(snapshot.musicVolume, forKey: Key.musicVolume)
        defaults.set(snapshot.effectsVolume, forKey: Key.effectsVolume)
        defaults.set(snapshot.isMuted, forKey: Key.isMuted)
    }

    private static func read(from defaults: UserDefaults) -> AppSettingsSnapshot {
        let defaultsSnapshot = AppSettingsSnapshot.default
        let reduceMotion: Bool
        if defaults.object(forKey: Key.reduceMotion) == nil {
            reduceMotion = defaultsSnapshot.reduceMotionEnabled
        } else {
            reduceMotion = defaults.bool(forKey: Key.reduceMotion)
        }

        let themeID: String
        if let stored = defaults.string(forKey: Key.themeID) {
            themeID = normalizeThemeID(stored)
        } else {
            themeID = defaultsSnapshot.themeID
        }

        let sokobanMusicTrackID: String
        if let stored = defaults.string(forKey: Key.sokobanMusicTrackID) {
            sokobanMusicTrackID = normalizeMusicTrackID(
                stored,
                fallback: MusicTrack.puzzlingID
            )
        } else if let legacy = defaults.string(forKey: Key.legacyMusicTrackID) {
            sokobanMusicTrackID = normalizeMusicTrackID(
                legacy,
                fallback: MusicTrack.puzzlingID
            )
        } else {
            sokobanMusicTrackID = defaultsSnapshot.sokobanMusicTrackID
        }

        let caveMusicTrackID: String
        if let stored = defaults.string(forKey: Key.caveMusicTrackID) {
            caveMusicTrackID = normalizeMusicTrackID(
                stored,
                fallback: MusicTrack.caveWonderID
            )
        } else {
            caveMusicTrackID = defaultsSnapshot.caveMusicTrackID
        }

        let music: Double
        if defaults.object(forKey: Key.musicVolume) == nil {
            music = defaultsSnapshot.musicVolume
        } else {
            music = clampVolume(defaults.double(forKey: Key.musicVolume))
        }

        let effects: Double
        if defaults.object(forKey: Key.effectsVolume) == nil {
            effects = defaultsSnapshot.effectsVolume
        } else {
            effects = clampVolume(defaults.double(forKey: Key.effectsVolume))
        }

        let muted: Bool
        if defaults.object(forKey: Key.isMuted) == nil {
            muted = defaultsSnapshot.isMuted
        } else {
            muted = defaults.bool(forKey: Key.isMuted)
        }

        return AppSettingsSnapshot(
            reduceMotionEnabled: reduceMotion,
            themeID: themeID,
            sokobanMusicTrackID: sokobanMusicTrackID,
            caveMusicTrackID: caveMusicTrackID,
            musicVolume: music,
            effectsVolume: effects,
            isMuted: muted
        )
    }
}
