/// Injectable playback surface for ``AudioDirector``.
///
/// Implementations must not block the caller and must not throw into session /
/// presentation flow. Tests use a spy; production uses bundled music and
/// procedural/file effects through AVFoundation.
@MainActor
protocol AudioPlaybackBackend: AnyObject {
    func applyTheme(_ theme: AudioTheme)
    func playEffect(_ cue: AudioCue)
    func setMusic(_ state: MusicPlaybackState)
    func stopAllEffects()
    func stopAll()
    /// Applies user music / effects gain and mute. Live updates are expected.
    func applyOutputSettings(_ settings: AudioOutputSettings)
}

/// Silent backend for tests that do not assert audio.
@MainActor
final class NoOpAudioPlaybackBackend: AudioPlaybackBackend {
    func applyTheme(_ theme: AudioTheme) {}
    func playEffect(_ cue: AudioCue) {}
    func setMusic(_ state: MusicPlaybackState) {}
    func stopAllEffects() {}
    func stopAll() {}
    func applyOutputSettings(_ settings: AudioOutputSettings) {}
}
