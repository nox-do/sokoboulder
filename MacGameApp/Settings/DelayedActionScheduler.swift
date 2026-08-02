import Foundation

/// Cancellable delayed work used by intro auto-dismiss (and similar UI timers).
protocol DelayedActionToken: AnyObject {
    func cancel()
}

/// Schedules main-queue delayed work without uncontrolled `sleep`.
protocol DelayedActionScheduler: AnyObject {
    @MainActor
    func schedule(after delay: TimeInterval, execute: @escaping @MainActor () -> Void) -> any DelayedActionToken
}

/// Production scheduler backed by `DispatchWorkItem`.
final class DispatchDelayedActionScheduler: DelayedActionScheduler {
    private final class Token: DelayedActionToken {
        let item: DispatchWorkItem
        init(item: DispatchWorkItem) { self.item = item }
        func cancel() { item.cancel() }
    }

    @MainActor
    func schedule(after delay: TimeInterval, execute: @escaping @MainActor () -> Void) -> any DelayedActionToken {
        let item = DispatchWorkItem { execute() }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return Token(item: item)
    }
}

/// Test scheduler that records pending work and fires only on demand.
@MainActor
final class ManualDelayedActionScheduler: DelayedActionScheduler {
    struct Pending {
        let delay: TimeInterval
        let execute: @MainActor () -> Void
        let token: Token
    }

    final class Token: DelayedActionToken {
        private(set) var isCancelled = false
        func cancel() { isCancelled = true }
    }

    private(set) var pending: [Pending] = []

    func schedule(after delay: TimeInterval, execute: @escaping @MainActor () -> Void) -> any DelayedActionToken {
        let token = Token()
        pending.append(Pending(delay: delay, execute: execute, token: token))
        return token
    }

    /// Fires the oldest non-cancelled pending action (FIFO).
    func fireNext() {
        while !pending.isEmpty {
            let next = pending.removeFirst()
            guard !next.token.isCancelled else { continue }
            next.execute()
            return
        }
    }

    func cancelAll() {
        for item in pending {
            item.token.cancel()
        }
        pending.removeAll()
    }

    var pendingCount: Int {
        pending.filter { !$0.token.isCancelled }.count
    }
}
