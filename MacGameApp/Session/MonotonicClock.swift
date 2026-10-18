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
