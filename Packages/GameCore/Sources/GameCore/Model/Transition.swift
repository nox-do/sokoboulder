/// Result of one rule-engine step: new state, ordered events, and undo-relevant outcome.
public struct Transition<State: Equatable & Sendable>: Equatable, Sendable {
    public let state: State
    public let events: [GameEvent]
    public let outcome: StepOutcome

    public init(state: State, events: [GameEvent], outcome: StepOutcome) {
        self.state = state
        self.events = events
        self.outcome = outcome
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
