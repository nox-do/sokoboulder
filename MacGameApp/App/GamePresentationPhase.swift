import Foundation

/// SwiftUI-facing presentation phase. Complements ``SessionPhase``:
/// session gates simulation input; this selects visible overlays.
enum GamePresentationPhase: Equatable, Sendable {
    case playing
    case paused
    /// Terminal revision is animating (or waiting on settle/timeout).
    case outcomeAnimating
    /// Result overlay is interactive.
    case outcomeAwaitingChoice
    /// Blocking recovery when a run file exists but cannot be restored.
    case runRecovery
    case faulted
}
