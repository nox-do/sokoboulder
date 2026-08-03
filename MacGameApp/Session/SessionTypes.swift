import GameCore

/// Session commands that are not core rule inputs.
///
/// Moves use ``GameSession/submitMove(_:)`` (or the test-facing enqueue/process
/// helpers) — not this enum.
enum SessionCommand: Equatable, Sendable {
    case undo
    case redo
    case restart
}

/// App-facing session phase for Sokoban and cave runs.
enum SessionPhase: Equatable, Sendable {
    /// Constructed but not yet bootstrapped via ``GameSession/start()``.
    case created
    /// Cave only: board visible, no simulation ticks until the first intent.
    case ready
    case playing
    /// Shell interruption; authoritative core state is unchanged.
    case paused
    case outcomePresenting
    case faulted
}

/// Optional app-shell transition accompanying a presentation update.
enum SessionAppTransition: Equatable, Sendable {
    case enterOutcomePresenting
    case returnToPlaying
}

/// Paired render/audio emission for one revision step.
struct SessionEmission: Equatable, Sendable {
    let render: RenderUpdate
    let audio: AudioUpdate
    let appTransition: SessionAppTransition?
}

/// Result of applying one session command or processing a queued move.
enum SessionApplyResult: Equatable, Sendable {
    /// No render/audio update (noop, pre-bootstrap, empty terminal ignore, …).
    case ignored
    case emitted(SessionEmission)
    /// Engine fault: no new snapshot/audio; keep last valid renderer frame.
    case faulted(message: String)
}
