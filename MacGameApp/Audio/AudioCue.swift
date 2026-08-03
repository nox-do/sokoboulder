/// Transient gameplay sound mapped from ``GameEvent``s.
///
/// Shared vocabulary for Sokoban and Cave. Themes point each cue at a
/// `shared/`, `sokoban/`, or `boulderDash/` WAV (or `null` for procedural).
enum AudioCue: String, Equatable, Sendable, CaseIterable {
    case movementStep
    case movementBlocked
    case objectPushed
    case objectLanded
    case collectiblePickedUp
    case objectiveCompleted
    case exitOpened
    case playerDied
    case timeExpired
    /// Sokoban-only negative tick when a crate leaves a goal.
    case goalLeft
}

/// Desired background music derived from ``AudioContext`` + active theme.
enum MusicPlaybackState: Equatable, Sendable {
    case stopped
    /// Loop the active theme's `music.playing` asset (silence if missing).
    case themeLoop
}
