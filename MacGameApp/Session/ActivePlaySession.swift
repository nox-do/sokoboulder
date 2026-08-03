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

    /// Whether Esc / focus-loss may open pause from an active play shell.
    var canEnterPauseFromPlaying: Bool {
        switch self {
        case .sokoban(let session):
            session.phase == .playing
        case .cave(let session):
            session.phase == .playing || session.phase == .ready
        }
    }

    var isPaused: Bool { phase == .paused }

    var isOutcomePresenting: Bool { phase == .outcomePresenting }

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

        switch self {
        case .sokoban(let session):
            return PlaySessionPublishedCapabilities(
                canUndo: sessionCommandsAllowed
                    && session.undoCount > 0
                    && (session.canAcceptSessionCommand || session.phase == .paused),
                canRedo: sessionCommandsAllowed
                    && session.redoCount > 0
                    && (session.canAcceptSessionCommand || session.phase == .paused),
                canRestart: sessionCommandsAllowed
                    && (session.phase == .playing
                        || session.phase == .paused
                        || session.phase == .outcomePresenting),
                canPause: presentationPhase == .playing && session.phase == .playing,
                canResume: presentationPhase == .paused
            )
        case .cave(let session):
            return PlaySessionPublishedCapabilities(
                canUndo: false,
                canRedo: false,
                canRestart: sessionCommandsAllowed
                    && (session.phase == .ready
                        || session.phase == .playing
                        || session.phase == .paused
                        || session.phase == .outcomePresenting),
                canPause: presentationPhase == .playing
                    && (session.phase == .playing || session.phase == .ready),
                canResume: presentationPhase == .paused
            )
        }
    }
}

struct PlaySessionPublishedCapabilities: Equatable, Sendable {
    var canUndo: Bool
    var canRedo: Bool
    var canRestart: Bool
    var canPause: Bool
    var canResume: Bool
}
