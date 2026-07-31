import GameCore

/// Session commands that are not core rule inputs.
///
/// Moves use ``GameSession/enqueueMove(_:)`` exclusively — not this enum.
enum SessionCommand: Equatable, Sendable {
    case undo
    case redo
    case restart
}

/// App-facing session phase for Sokoban in Phase 2.
enum SessionPhase: Equatable, Sendable {
    /// Constructed but not yet bootstrapped via ``GameSession/start()``.
    case created
    case playing
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
