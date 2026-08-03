import AppKit
import GameCore

/// Semantic gameplay intent produced by ``InputMapper``.
///
/// Independent of session phase, renderer, and UI mode.
enum GameplayIntent: Equatable, Sendable {
    case move(Direction)
    case undo
    case redo
    case restart
    case pause
}

/// Stateless NSEvent → ``GameplayIntent`` mapping for Sokoban Phase 2.
///
/// Knows nothing about ``GameSession``, rendering, or app shell state.
enum InputMapper {
    /// Translates a key event into a gameplay intent, or `nil` when ignored.
    ///
    /// Rules:
    /// - Only key-down events produce intents.
    /// - Synthetic macOS key-repeats (`isARepeat`) are discarded.
    /// - Command / Control / Option combinations are ignored (menus own ⌘Z / ⇧⌘Z).
    /// - Caps Lock and similar non-action modifiers do not reject mapping.
    static func intent(from event: NSEvent) -> GameplayIntent? {
        guard event.type == .keyDown else { return nil }
        guard !event.isARepeat else { return nil }

        let blocking: NSEvent.ModifierFlags = [.command, .control, .option]
        if !event.modifierFlags.intersection(blocking).isEmpty {
            return nil
        }

        if let direction = moveDirection(keyCode: event.keyCode) {
            return .move(direction)
        }

        switch event.keyCode {
        case KeyCode.z:
            return .undo
        case KeyCode.r:
            return .restart
        case KeyCode.escape:
            return .pause
        default:
            return nil
        }
    }

    /// Movement direction for a hardware key, including key-up tracking.
    static func moveDirection(keyCode: UInt16) -> Direction? {
        switch keyCode {
        case KeyCode.upArrow, KeyCode.w:
            return .up
        case KeyCode.downArrow, KeyCode.s:
            return .down
        case KeyCode.leftArrow, KeyCode.a:
            return .left
        case KeyCode.rightArrow, KeyCode.d:
            return .right
        default:
            return nil
        }
    }
}

/// Hardware key codes used by ``InputMapper``.
enum KeyCode {
    static let a: UInt16 = 0
    static let s: UInt16 = 1
    static let d: UInt16 = 2
    static let w: UInt16 = 13
    static let r: UInt16 = 15
    static let z: UInt16 = 6
    static let escape: UInt16 = 53
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
    static let `return`: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let space: UInt16 = 49
}
