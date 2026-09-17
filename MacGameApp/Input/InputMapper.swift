import AppKit
import GameCore

/// Semantic gameplay intent produced by ``InputMapper``.
///
/// Independent of session phase, renderer, and UI mode.
enum GameplayIntent: Equatable, Sendable {
    case move(Direction)
    case wait
    case undo
    case redo
    case restart
    case pause
    /// Presentation-only bookmark on the goal the player occupies.
    case toggleGoalMarker
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
    /// - Letter shortcuts (Z/R and ⌘ variants) use ``charactersIgnoringModifiers``
    ///   so QWERTZ / Dvorak still match the labeled key (Apple keyboard-equivalent
    ///   guidance). Arrow / WASD movement stays on hardware ``keyCode``.
    /// - Other Command / Control / Option combinations are ignored.
    /// - Caps Lock and similar non-action modifiers do not reject mapping.
    static func intent(from event: NSEvent) -> GameplayIntent? {
        guard event.type == .keyDown else { return nil }
        guard !event.isARepeat else { return nil }

        if let shortcut = menuEquivalentIntent(from: event) {
            return shortcut
        }

        let blocking: NSEvent.ModifierFlags = [.command, .control, .option]
        if !event.modifierFlags.intersection(blocking).isEmpty {
            return nil
        }

        if let direction = moveDirection(keyCode: event.keyCode) {
            return .move(direction)
        }

        if event.keyCode == KeyCode.space {
            return .wait
        }
        if event.keyCode == KeyCode.escape {
            return .pause
        }

        switch letterKey(from: event) {
        case "z":
            return .undo
        case "r":
            return .restart
        case "m":
            return .toggleGoalMarker
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

    /// Whether this event is the layout-independent Undo letter (Z).
    static func isUndoLetter(_ event: NSEvent) -> Bool {
        letterKey(from: event) == "z"
    }

    /// Whether this event is the layout-independent Restart letter (R).
    static func isRestartLetter(_ event: NSEvent) -> Bool {
        letterKey(from: event) == "r"
    }

    /// Edit/Game menu key equivalents that must reach gameplay via the local monitor.
    ///
    /// Uses characters, not ANSI key codes: on German QWERTZ the labeled Z key is
    /// `kVK_ANSI_Y` (16), while `kVK_ANSI_Z` (6) is the labeled Y key.
    private static func menuEquivalentIntent(from event: NSEvent) -> GameplayIntent? {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard mods.contains(.command) else { return nil }
        guard !mods.contains(.control), !mods.contains(.option) else { return nil }

        switch letterKey(from: event) {
        case "z":
            return mods.contains(.shift) ? .redo : .undo
        case "r":
            return mods.contains(.shift) ? nil : .restart
        default:
            return nil
        }
    }

    private static func letterKey(from event: NSEvent) -> String? {
        guard let raw = event.charactersIgnoringModifiers, raw.count == 1 else {
            return nil
        }
        return raw.lowercased()
    }
}

/// Hardware key codes used by ``InputMapper``.
///
/// ANSI letter codes are US-QWERTY physical positions. Prefer
/// ``charactersIgnoringModifiers`` for letter shortcuts that must follow the
/// user's layout (Undo Z, Restart R).
enum KeyCode {
    static let a: UInt16 = 0
    static let s: UInt16 = 1
    static let d: UInt16 = 2
    static let w: UInt16 = 13
    static let r: UInt16 = 15
    static let u: UInt16 = 32
    /// US-QWERTY Z / German QWERTZ Y physical key (`kVK_ANSI_Z`).
    static let z: UInt16 = 6
    /// US-QWERTY Y / German QWERTZ Z physical key (`kVK_ANSI_Y`).
    static let y: UInt16 = 16
    static let escape: UInt16 = 53
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
    static let `return`: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let space: UInt16 = 49
    /// US-QWERTY / QWERTZ M (`kVK_ANSI_M`). Letter mapping still uses characters.
    static let m: UInt16 = 46
}
