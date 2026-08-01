/// Injectable playback surface for ``AudioDirector``.
///
/// Implementations must not block the caller and must not throw into session /
/// presentation flow. Tests use a spy; production uses a procedural AVFAudio
/// backend so no foreign assets are required for Phase 2 step 7.
@MainActor
protocol AudioPlaybackBackend: AnyObject {
    func playEffect(_ cue: AudioCue)
    func setMusic(_ state: MusicPlaybackState)
    func stopAllEffects()
    func stopAll()
}

/// Silent backend for tests that do not assert audio.
@MainActor
final class NoOpAudioPlaybackBackend: AudioPlaybackBackend {
    func playEffect(_ cue: AudioCue) {}
    func setMusic(_ state: MusicPlaybackState) {}
    func stopAllEffects() {}
    func stopAll() {}
}
