import Foundation

/// Data-only model for the shared settings overlay.
struct SettingsPresentation: Equatable, Sendable {
    var title: String
    var backTitle: String
    var themeTitle: String
    var themeOptions: [ThemeOption]
    var selectedThemeID: String
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
}
