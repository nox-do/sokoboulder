/// Typed failure from a public rule transition when essential pre- or postconditions fail.
///
/// Normal blocked moves and inputs after level completion are not faults; they
/// return a deterministic ``Transition`` with ``StepOutcome/blocked``.
public enum EngineFault: Error, Equatable, Sendable {
    /// An essential world invariant was violated.
    case invariantViolated(String)
}
