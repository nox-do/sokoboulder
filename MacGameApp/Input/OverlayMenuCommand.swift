import AppKit

/// Keyboard commands owned by menu / overlay phases (not gameplay).
enum OverlayMenuCommand: Equatable, Sendable {
    case moveUp
    case moveDown
    case moveLeft
    case moveRight
    case activate
    case cancel
}

enum OverlayMenuCommandMapper {
    /// Maps a key event for overlay handling. Returns `nil` when the key is irrelevant.
    static func command(from event: NSEvent) -> OverlayMenuCommand? {
        guard event.type == .keyDown else { return nil }

        let blocking: NSEvent.ModifierFlags = [.command, .control, .option]
        if !event.modifierFlags.intersection(blocking).isEmpty {
            return nil
        }

        switch event.keyCode {
        case KeyCode.upArrow:
            return .moveUp
        case KeyCode.downArrow:
            return .moveDown
        case KeyCode.leftArrow:
            return .moveLeft
        case KeyCode.rightArrow:
            return .moveRight
        case KeyCode.return, KeyCode.keypadEnter, KeyCode.space:
            return .activate
        case KeyCode.escape:
            return .cancel
        default:
            return nil
        }
    }
}
