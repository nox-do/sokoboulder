import Foundation

/// Data-only model for the shared settings overlay.
struct SettingsPresentation: Equatable, Sendable {
    var title: String
    var backTitle: String
    var themeTitle: String
    var themeOptions: [ThemeOption]
    var selectedThemeID: String
    /// One music picker group per game that has selectable tracks.
    var musicTrackGroups: [MusicTrackGroup]
    var reduceMotionTitle: String
    var reduceMotionDetail: String
    var reduceMotionEnabled: Bool
    var musicVolumeTitle: String
    var musicVolume: Double
    var effectsVolumeTitle: String
    var effectsVolume: Double
    var muteTitle: String
    var isMuted: Bool

    struct ThemeOption: Equatable, Sendable, Identifiable {
        var id: String
        var title: String
    }

    struct MusicTrackOption: Equatable, Sendable, Identifiable {
        var id: String
        var title: String
    }

    struct MusicTrackGroup: Equatable, Sendable, Identifiable {
        /// Stable focus id, e.g. `musicTrack.sokoban`.
        var id: String
        var game: AudioGameMode
        var title: String
        var hint: String
        var options: [MusicTrackOption]
        var selectedTrackID: String
        var creditSummary: String
        var attributionNotice: String?
    }
}
