import Foundation

/// SwiftUI-facing presentation phase. Complements ``SessionPhase``:
/// session gates simulation input; this selects visible overlays.
enum GamePresentationPhase: Equatable, Sendable {
    /// Top-level game picker (Sokoban / Höhle). Entry after boot when not restoring a run.
    case gameSelection
    /// Sokoban hub: continue / level-select / help / settings.
    case launchMenu
    /// Minimal campaign level list.
    case levelSelection
    /// Short skippable tutorial hint before the first move of a fresh level.
    case levelIntro
    case playing
    case paused
    /// Shared help / controls overview (returns to ``OverlayReturnOrigin``).
    case help
    /// Shared settings overlay (returns to ``OverlayReturnOrigin``).
    case settings
    /// Board remains visible while the result animation and audio finish.
    case outcomePresenting
    /// Result overlay is interactive.
    case outcomeAwaitingChoice
    /// Blocking recovery when a run file exists but cannot be restored.
    case runRecovery
    case faulted

    var inputMode: GameplayInputRouter.Mode {
        switch self {
        case .playing: .gameplay
        case .paused: .paused
        case .levelIntro: .levelIntro
        case .outcomePresenting, .outcomeAwaitingChoice: .outcomePresenting
        default: .modalBlocked
        }
    }
}
