/// Transient gameplay sound mapped from ``GameEvent``s.
enum AudioCue: Equatable, Sendable {
    case step
    case blocked
    case cratePushed
    case goalEntered
    case goalLeft
    case levelCompleted
}

/// Desired background music derived from ``AudioContext``.
enum MusicPlaybackState: Equatable, Sendable {
    case stopped
    case sokobanLoop
}
