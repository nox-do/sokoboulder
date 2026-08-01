import AppKit
import GameCore

/// Routed result from ``GameplayInputRouter`` for the app shell / session.
enum RoutedInput: Equatable, Sendable {
    /// Forward to the session (move / undo / redo / restart / pause).
    case gameplay(GameplayIntent)
    /// Outcome dialog confirmation after the key-up gate has cleared.
    case outcomeAction
    /// Dismiss the level-intro hint overlay.
    case dismissIntro
}

/// Distinguishes an irrelevant platform event from one deliberately swallowed
/// by an input gate. Overlay event monitors must not forward `.consumed` events
/// to SwiftUI controls.
enum InputRoutingDecision: Equatable, Sendable {
    case unhandled
    case consumed
    case routed(RoutedInput)
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
        case levelIntro
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

    /// Blocks gameplay while a skippable level hint is visible.
    func enterLevelIntro() {
        mode = .levelIntro
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

    /// Opens the outcome confirm gate while keeping currently held keys blocked.
    ///
    /// Used when entering ``GamePresentationPhase/outcomeAwaitingChoice`` so a
    /// Return/Space that skipped the presentation cannot also confirm.
    func releaseOutcomeLocksPreservingPressedKeys() {
        guard mode == .outcomePresenting else { return }
        lockedKeyCodes.removeAll(keepingCapacity: true)
        outcomeGateOpen = true
    }

    /// Routes a platform key event. Key-ups never produce routed input.
    func route(_ event: NSEvent) -> RoutedInput? {
        guard case .routed(let input) = routeDecision(event) else { return nil }
        return input
    }

    /// Routes an event while preserving whether a gate deliberately consumed it.
    func routeDecision(_ event: NSEvent) -> InputRoutingDecision {
        switch event.type {
        case .keyDown:
            return routeKeyDownDecision(event)
        case .keyUp:
            let wasTracked = pressedKeyCodes.contains(event.keyCode)
                || lockedKeyCodes.contains(event.keyCode)
            routeKeyUp(event)
            if mode == .outcomePresenting,
               wasTracked || isOutcomeConfirmKey(event.keyCode)
            {
                return .consumed
            }
            return .unhandled
        default:
            return .unhandled
        }
    }

    // MARK: - Private

    private func routeKeyDownDecision(_ event: NSEvent) -> InputRoutingDecision {
        let keyCode = event.keyCode

        switch mode {
        case .modalBlocked:
            return .unhandled

        case .levelIntro:
            trackPress(keyCode, from: event)
            guard !event.isARepeat else {
                return isIntroDismissKey(keyCode) ? .consumed : .unhandled
            }
            if isIntroDismissKey(keyCode) {
                return .routed(.dismissIntro)
            }
            return .unhandled

        case .paused:
            trackPress(keyCode, from: event)
            guard !event.isARepeat else {
                return isPausedCommandKey(event) ? .consumed : .unhandled
            }
            // Escape resumes; R/Z still reach the shell (session may resume first).
            if let intent = InputMapper.intent(from: event) {
                switch intent {
                case .pause, .restart, .undo, .redo:
                    return .routed(.gameplay(intent))
                case .move:
                    return .unhandled
                }
            }
            return .unhandled

        case .gameplay:
            // Track gameplay and confirm keys even when they produce no intent,
            // so a held Return/Space cannot later slip through the outcome gate.
            trackPress(keyCode, from: event)
            guard let intent = InputMapper.intent(from: event) else { return .unhandled }
            return .routed(.gameplay(intent))

        case .outcomePresenting:
            // Repeats must never confirm or re-issue commands.
            guard !event.isARepeat else {
                return isOutcomeOwnedKey(event) ? .consumed : .unhandled
            }

            let wasAlreadyPressed = pressedKeyCodes.contains(keyCode)
            if isOutcomeOwnedKey(event) {
                pressedKeyCodes.insert(keyCode)
            }

            if lockedKeyCodes.contains(keyCode) {
                return .consumed
            }

            if !outcomeGateOpen {
                return isOutcomeOwnedKey(event) ? .consumed : .unhandled
            }

            // Session commands remain available through the same intent mapping.
            if let intent = InputMapper.intent(from: event) {
                switch intent {
                case .undo, .redo, .restart:
                    return .routed(.gameplay(intent))
                case .move, .pause:
                    return .unhandled
                }
            }

            // Confirm only on a fresh, independent key-down of Return/Space.
            if isOutcomeConfirmKey(keyCode), !wasAlreadyPressed {
                return .routed(.outcomeAction)
            }
            if isOutcomeConfirmKey(keyCode) {
                return .consumed
            }
            return .unhandled
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

    private func isIntroDismissKey(_ keyCode: UInt16) -> Bool {
        keyCode == KeyCode.return
            || keyCode == KeyCode.space
            || keyCode == KeyCode.escape
    }

    private func isPausedCommandKey(_ event: NSEvent) -> Bool {
        guard !hasBlockingModifiers(event) else { return false }
        return event.keyCode == KeyCode.escape
            || event.keyCode == KeyCode.r
            || event.keyCode == KeyCode.z
    }

    private func isOutcomeOwnedKey(_ event: NSEvent) -> Bool {
        guard !hasBlockingModifiers(event) else { return false }
        return isOutcomeConfirmKey(event.keyCode)
            || event.keyCode == KeyCode.r
            || event.keyCode == KeyCode.z
    }

    private func hasBlockingModifiers(_ event: NSEvent) -> Bool {
        let blocking: NSEvent.ModifierFlags = [.command, .control, .option]
        return !event.modifierFlags.intersection(blocking).isEmpty
    }
}
