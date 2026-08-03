import Foundation

/// Data-only model for the shared settings overlay.
struct SettingsPresentation: Equatable, Sendable {
    var title: String
    var backTitle: String
    var themeTitle: String
    var themeOptions: [ThemeOption]
    var selectedThemeID: String
    var musicTrackTitle: String
    var musicTrackHint: String
    var musicTrackOptions: [MusicTrackOption]
    var selectedMusicTrackID: String
    /// Per-song credit under the track picker (`Title — Author (License)`).
    var selectedMusicCreditSummary: String
    /// Optional required attribution line (e.g. CC-BY notice).
    var selectedMusicAttributionNotice: String?
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
}
