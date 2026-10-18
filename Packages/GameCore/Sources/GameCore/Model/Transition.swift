/// Result of one rule-engine step: new state, ordered events, and undo-relevant outcome.
public struct Transition<State: Equatable & Sendable>: Equatable, Sendable {
    public let state: State
    public let events: [GameEvent]
    public let outcome: StepOutcome
    /// Optional diagnostic for a blocked move; does not affect history.
    public let blockReason: MovementBlockReason?

    public init(
        state: State, events: [GameEvent], outcome: StepOutcome,
        blockReason: MovementBlockReason? = nil
    ) {
        self.state = state
        self.events = events
        self.outcome = outcome
        self.blockReason = blockReason
    }
}

/// Whether a step should update undo history / statistics.
///
/// Callers must not infer this from events or by comparing states.
public enum StepOutcome: Equatable, Sendable {
    case blocked
    case changed
    case terminal(PlayStatus)
}

/// Why the movement rule rejected an attempted move.
public enum MovementBlockReason: Equatable, Sendable {
    case obstacle
    case staticDeadlock
}
