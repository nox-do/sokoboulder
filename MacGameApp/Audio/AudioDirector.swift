import GameCore

/// Session-facing audio service: revisioned ``AudioUpdate``s plus shell lifecycle.
///
/// Pause / focus loss / fault use ``interrupt()`` / ``resumePlayback()`` /
/// ``reset()`` — they are not revisioned ``AudioUpdate``s.
@MainActor
final class AudioDirector {
    private let backend: any AudioPlaybackBackend

    private(set) var lastAppliedRevision: UInt64?
    private var desiredMusic: MusicPlaybackState = .stopped
    private var interrupted = false

    init(backend: any AudioPlaybackBackend = ProceduralAudioPlaybackBackend()) {
        self.backend = backend
    }

    /// Applies one session audio emission. Never blocks presentation.
    func apply(_ update: AudioUpdate) {
        if let last = lastAppliedRevision, update.targetRevision <= last {
            // Duplicate or stale: drop entirely (no cues, no revision rewind).
            return
        }

        desiredMusic = Self.musicState(for: update.context)

        if let last = lastAppliedRevision, update.targetRevision > last + 1 {
            // Forward gap: ignore transient events; cut voices and align music.
            lastAppliedRevision = update.targetRevision
            backend.stopAllEffects()
            alignMusicIfAudible()
            return
        }

        // Contiguous (or first applied update).
        lastAppliedRevision = update.targetRevision

        switch update.delivery {
        case .perform:
            if !interrupted {
                playCues(from: update.events)
            }
        case .synchronize:
            // Hard-resync / undo / redo / restart: never leave old cues ringing.
            backend.stopAllEffects()
        }

        alignMusicIfAudible()
    }

    /// Pause / focus loss: stop effect voices and silence music without forgetting
    /// the desired music state.
    func interrupt() {
        interrupted = true
        backend.stopAllEffects()
        backend.setMusic(.stopped)
    }

    /// Resume after ``interrupt()``: restore music from the last known context.
    func resumePlayback() {
        interrupted = false
        alignMusicIfAudible()
    }

    /// Fault / level reload: forget revision tracking and silence everything.
    func reset() {
        interrupted = false
        lastAppliedRevision = nil
        desiredMusic = .stopped
        backend.stopAll()
    }

    // MARK: - Mapping

    static func musicState(for context: AudioContext) -> MusicPlaybackState {
        switch context.status {
        case .playing:
            return .sokobanLoop
        case .completed, .failed:
            return .stopped
        }
    }

    /// Maps ordered events to cues. A push plays only the push cue (no step).
    static func cues(from events: [GameEvent]) -> [AudioCue] {
        let pushed = events.contains { event in
            if case .objectPushed = event { return true }
            return false
        }

        var cues: [AudioCue] = []
        for event in events {
            switch event {
            case .movementBlocked:
                cues.append(.blocked)
            case .objectPushed:
                cues.append(.cratePushed)
            case .entityMoved(let entity, _, _) where entity.kind == .player:
                if !pushed {
                    cues.append(.step)
                }
            case .crateEnteredGoal:
                cues.append(.goalEntered)
            case .crateLeftGoal:
                cues.append(.goalLeft)
            case .levelCompleted:
                cues.append(.levelCompleted)
            default:
                break
            }
        }
        return cues
    }

    private func playCues(from events: [GameEvent]) {
        for cue in Self.cues(from: events) {
            backend.playEffect(cue)
        }
    }

    private func alignMusicIfAudible() {
        guard !interrupted else { return }
        backend.setMusic(desiredMusic)
    }
}
