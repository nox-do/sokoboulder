/// Transient gameplay sound mapped from ``GameEvent``s.
enum AudioCue: String, Equatable, Sendable, CaseIterable {
    case step
    case blocked
    case cratePushed
    case goalEntered
    case goalLeft
    case levelCompleted
}

/// Desired background music derived from ``AudioContext`` + active theme.
enum MusicPlaybackState: Equatable, Sendable {
    case stopped
    /// Loop the active theme's `music.playing` asset (silence if missing).
    case themeLoop
}
