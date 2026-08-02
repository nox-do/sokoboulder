import Combine
import Foundation

/// Persisted presentation / audio preferences (Phase 3.3).
///
/// Audio-theme mapping and manifests arrive in Phase 3.5; this store is the
/// reusable settings surface those themes will read.
struct AppSettingsSnapshot: Equatable, Sendable {
    /// App-local reduce-motion preference (OR’d with the system setting).
    var reduceMotionEnabled: Bool
    /// Selected visual theme ID (`theme.standard`, `theme.highContrast`, …).
    var themeID: String
    /// Music bus gain in `0...1`.
    var musicVolume: Double
    /// Effects / jingles bus gain in `0...1`.
    var effectsVolume: Double
    /// When true, music and effects are silent regardless of volume sliders.
    var isMuted: Bool

    static let `default` = AppSettingsSnapshot(
        reduceMotionEnabled: false,
        themeID: VisualTheme.standardID,
        musicVolume: 0.8,
        effectsVolume: 1.0,
        isMuted: false
    )
}

/// Injectable UserDefaults-backed settings. Tests pass an isolated suite name.
@MainActor
final class AppSettingsStore: ObservableObject {
    static let suitePrefix = "com.sokoboulder.app.settings"

    private enum Key {
        static let reduceMotion = "settings.reduceMotion"
        static let themeID = "settings.themeID"
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

    /// Seeds the theme ID once from the theme catalog when no preference exists yet.
    func seedThemeIDFromCatalogIfUnset(_ catalogDefaultThemeID: String) {
        guard !hasPersistedThemeID else { return }
        themeID = Self.normalizeThemeID(catalogDefaultThemeID)
    }

    var themeID: String {
        get { snapshot.themeID }
        set { update { $0.themeID = Self.normalizeThemeID(newValue) } }
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
        guard !trimmed.isEmpty else { return VisualTheme.standardID }
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
            musicVolume: music,
            effectsVolume: effects,
            isMuted: muted
        )
    }
}
