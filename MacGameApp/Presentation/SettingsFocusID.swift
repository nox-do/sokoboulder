import Foundation

/// Canonical settings overlay keyboard focus identifiers.
enum SettingsFocusID {
    static let theme = "theme"
    static let reduceMotion = "reduceMotion"
    static let music = "music"
    static let effects = "effects"
    static let mute = "mute"
    static let back = "back"

    static func musicTrack(for game: AudioGameMode) -> String {
        "musicTrack.\(game.rawValue)"
    }

    /// Focus order used by the settings keyboard contract.
    static func keyboardFocusOrder(
        showsThemePicker: Bool,
        musicTrackFocusIDs: [String]
    ) -> [String] {
        var order = [reduceMotion, music, effects, mute, back]
        for focusID in musicTrackFocusIDs.reversed() {
            order.insert(focusID, at: 0)
        }
        if showsThemePicker {
            order.insert(theme, at: 0)
        }
        return order
    }
}
