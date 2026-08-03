import Foundation

/// Monotonic time source shared by cave input stamps and ``CaveSession/advance(to:)``.
protocol MonotonicClock: Sendable {
    func now() -> TimeInterval
}

/// Production clock based on system uptime (unaffected by wall-clock adjustments).
struct SystemUptimeClock: MonotonicClock {
    func now() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}

/// Test double with an explicitly advanced timeline.
final class ManualClock: MonotonicClock, @unchecked Sendable {
    private(set) var current: TimeInterval

    init(start: TimeInterval = 0) {
        self.current = start
    }

    func now() -> TimeInterval { current }

    func advance(by delta: TimeInterval) {
        current += delta
    }

    func set(_ value: TimeInterval) {
        current = value
    }
}
