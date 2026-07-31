import AppKit
import GameCore

/// Routed result from ``GameplayInputRouter`` for the app shell / session.
enum RoutedInput: Equatable, Sendable {
    /// Forward to the session (move / undo / redo / restart / pause).
    case gameplay(GameplayIntent)
    /// Outcome dialog confirmation after the key-up gate has cleared.
    case outcomeAction
}

/// Shell-side input policy for Sokoban.
///
/// ``InputMapper`` stays a pure event→intent map. This router applies
/// mode-dependent gates: modal UI, pause/focus clearing, and the outcome
/// key-up latch so a terminal move cannot confirm the result dialog.
@MainActor
final class GameplayInputRouter {
    enum Mode: Equatable, Sendable {
        case gameplay
        case paused
        case outcomePresenting
        case modalBlocked
    }

    private(set) var mode: Mode = .gameplay

    /// Currently held key codes (from key-down without matching up).
    private(set) var pressedKeyCodes: Set<UInt16> = []

    /// Keys held when entering outcome; blocked until their key-up arrives.
    private(set) var lockedKeyCodes: Set<UInt16> = []

    /// After locked keys release, a later independent key-down may confirm outcome.
    private(set) var outcomeGateOpen = false

    /// Clears held / locked keys. Used by pause and focus loss.
    func clearPendingInputs() {
        pressedKeyCodes.removeAll(keepingCapacity: true)
        lockedKeyCodes.removeAll(keepingCapacity: true)
        if mode != .outcomePresenting {
            outcomeGateOpen = false
        } else {
            outcomeGateOpen = true
        }
    }

    func enterGameplay() {
        mode = .gameplay
        pressedKeyCodes.removeAll(keepingCapacity: true)
        lockedKeyCodes.removeAll(keepingCapacity: true)
        outcomeGateOpen = false
    }

    func enterPaused() {
        mode = .paused
        pressedKeyCodes.removeAll(keepingCapacity: true)
        lockedKeyCodes.removeAll(keepingCapacity: true)
        outcomeGateOpen = false
    }

    func enterModalBlocked() {
        mode = .modalBlocked
        pressedKeyCodes.removeAll(keepingCapacity: true)
        lockedKeyCodes.removeAll(keepingCapacity: true)
        outcomeGateOpen = false
    }

    /// Locks currently pressed keys; only a later key-down after their matching
    /// key-ups may produce ``RoutedInput/outcomeAction``.
    func enterOutcomePresenting() {
        mode = .outcomePresenting
        lockedKeyCodes = pressedKeyCodes
        outcomeGateOpen = lockedKeyCodes.isEmpty
    }

    /// Routes a platform key event. Key-ups never produce routed input.
    func route(_ event: NSEvent) -> RoutedInput? {
        switch event.type {
        case .keyDown:
            return routeKeyDown(event)
        case .keyUp:
            routeKeyUp(event)
            return nil
        default:
            return nil
        }
    }

    // MARK: - Private

    private func routeKeyDown(_ event: NSEvent) -> RoutedInput? {
        let keyCode = event.keyCode

        switch mode {
        case .modalBlocked:
            return nil

        case .paused:
            trackPress(keyCode, from: event)
            guard !event.isARepeat else { return nil }
            // Escape resumes; R/Z still reach the shell (session may resume first).
            if let intent = InputMapper.intent(from: event) {
                switch intent {
                case .pause, .restart, .undo, .redo:
                    return .gameplay(intent)
                case .move:
                    return nil
                }
            }
            return nil

        case .gameplay:
            // Track gameplay and confirm keys even when they produce no intent,
            // so a held Return/Space cannot later slip through the outcome gate.
            trackPress(keyCode, from: event)
            guard let intent = InputMapper.intent(from: event) else { return nil }
            return .gameplay(intent)

        case .outcomePresenting:
            // Repeats must never confirm or re-issue commands.
            guard !event.isARepeat else { return nil }

            let wasAlreadyPressed = pressedKeyCodes.contains(keyCode)
            pressedKeyCodes.insert(keyCode)

            if lockedKeyCodes.contains(keyCode) {
                return nil
            }

            if !outcomeGateOpen {
                return nil
            }

            // Session commands remain available through the same intent mapping.
            if let intent = InputMapper.intent(from: event) {
                switch intent {
                case .undo, .redo, .restart:
                    return .gameplay(intent)
                case .move, .pause:
                    return nil
                }
            }

            // Confirm only on a fresh, independent key-down of Return/Space.
            if isOutcomeConfirmKey(keyCode), !wasAlreadyPressed {
                return .outcomeAction
            }
            return nil
        }
    }

    private func routeKeyUp(_ event: NSEvent) {
        let keyCode = event.keyCode
        pressedKeyCodes.remove(keyCode)

        guard mode == .outcomePresenting else { return }
        guard lockedKeyCodes.contains(keyCode) else { return }

        lockedKeyCodes.remove(keyCode)
        if lockedKeyCodes.isEmpty {
            outcomeGateOpen = true
        }
    }

    private func trackPress(_ keyCode: UInt16, from event: NSEvent) {
        guard !event.isARepeat else { return }
        // Always record confirm keys; also record anything the mapper cares about.
        if isOutcomeConfirmKey(keyCode) || InputMapper.intent(from: event) != nil {
            pressedKeyCodes.insert(keyCode)
        }
    }

    private func isOutcomeConfirmKey(_ keyCode: UInt16) -> Bool {
        keyCode == KeyCode.return || keyCode == KeyCode.space
    }
}
