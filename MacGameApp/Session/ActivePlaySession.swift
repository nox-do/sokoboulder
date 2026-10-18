import Foundation
import GameCore

/// Shell-facing adapter over the active Sokoban or Cave session.
@MainActor
enum ActivePlaySession {
    case sokoban(GameSession)
    case cave(CaveSession)

    var isCave: Bool {
        if case .cave = self { return true }
        return false
    }

    var sokoban: GameSession? {
        if case .sokoban(let session) = self { return session }
        return nil
    }

    var cave: CaveSession? {
        if case .cave(let session) = self { return session }
        return nil
    }

    var phase: SessionPhase {
        switch self {
        case .sokoban(let session): session.phase
        case .cave(let session): session.phase
        }
    }

    var revision: UInt64 {
        switch self {
        case .sokoban(let session): session.revision
        case .cave(let session): session.revision
        }
    }

    /// Ready cave runs and playing sessions accept interaction and may be paused.
    var isInteractive: Bool { phase == .ready || phase == .playing }

    var isPaused: Bool { phase == .paused }

    var isOutcomePresenting: Bool { phase == .outcomePresenting }

    /// Delay before the choice overlay after a terminal emission.
    var outcomeOverlayDelay: TimeInterval {
        switch self {
        case .cave: 1.2
        case .sokoban: 1.5
        }
    }

    func pause() {
        switch self {
        case .sokoban(let session): session.pause()
        case .cave(let session): session.pause()
        }
    }

    func resume() {
        switch self {
        case .sokoban(let session): session.resume()
        case .cave(let session): session.resume()
        }
    }

    /// HUD / menu capability flags derived from session + presentation phase.
    func publishedCapabilities(
        presentationPhase: GamePresentationPhase
    ) -> PlaySessionPublishedCapabilities {
        let sessionCommandsAllowed =
            presentationPhase != .help && presentationPhase != .settings

        let canUseHistory =
            sessionCommandsAllowed
            && (phase == .playing || isPaused || isOutcomePresenting)
        return PlaySessionPublishedCapabilities(
            canUndo: canUseHistory && (sokoban?.undoCount ?? 0) > 0,
            canRedo: canUseHistory && (sokoban?.redoCount ?? 0) > 0,
            canRestart: sessionCommandsAllowed && (isInteractive || isPaused || isOutcomePresenting),
            canPause: presentationPhase == .playing && isInteractive,
            canResume: presentationPhase == .paused
        )
    }
}

struct PlaySessionPublishedCapabilities: Equatable, Sendable {
    var canUndo: Bool
    var canRedo: Bool
    var canRestart: Bool
    var canPause: Bool
    var canResume: Bool
}
