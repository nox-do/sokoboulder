import AppKit
import Foundation
import GameCore

/// App-owned movement hold-repeat for Sokoban (not macOS `isARepeat`).
///
/// First key-down fires immediately. After ``initialDelay``, the last pressed
/// still-held direction repeats every ``repeatInterval`` until released.
@MainActor
final class SokobanMoveHoldRepeater {
    static let defaultInitialDelay: TimeInterval = 0.30
    static let defaultRepeatInterval: TimeInterval = 0.16

    var initialDelay: TimeInterval = defaultInitialDelay
    var repeatInterval: TimeInterval = defaultRepeatInterval

    /// Invoked for the initial press and each scheduled repeat.
    var onFire: ((Direction) -> Void)?

    private var heldKeys: [(keyCode: UInt16, direction: Direction)] = []
    private var pendingWork: DispatchWorkItem?

    var isHolding: Bool { !heldKeys.isEmpty }

    var activeDirection: Direction? { heldKeys.last?.direction }

    /// Records a fresh movement key-down and fires once immediately.
    func noteKeyDown(keyCode: UInt16, direction: Direction) {
        heldKeys.removeAll { $0.keyCode == keyCode }
        heldKeys.append((keyCode, direction))
        onFire?(direction)
        schedule(after: initialDelay)
    }

    /// Drops a released key; continues repeating the last remaining hold.
    func noteKeyUp(keyCode: UInt16) {
        let wasHolding = !heldKeys.isEmpty
        heldKeys.removeAll { $0.keyCode == keyCode }
        guard wasHolding else { return }
        if heldKeys.isEmpty {
            cancel()
        } else {
            schedule(after: repeatInterval)
        }
    }

    func clear() {
        heldKeys.removeAll(keepingCapacity: true)
        cancel()
    }

    private func schedule(after delay: TimeInterval) {
        cancelTimerOnly()
        let work = DispatchWorkItem { [weak self] in
            self?.fireRepeat()
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func fireRepeat() {
        guard let direction = activeDirection else {
            cancel()
            return
        }
        onFire?(direction)
        schedule(after: repeatInterval)
    }

    private func cancel() {
        cancelTimerOnly()
    }

    private func cancelTimerOnly() {
        pendingWork?.cancel()
        pendingWork = nil
    }
}
