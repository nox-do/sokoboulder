import GameCore
@testable import MacGameApp

/// Records playback calls for AudioDirector contract tests (no audio device).
@MainActor
final class SpyAudioPlaybackBackend: AudioPlaybackBackend {
    enum Call: Equatable, Sendable {
        case playEffect(AudioCue)
        case setMusic(MusicPlaybackState)
        case stopAllEffects
        case stopAll
    }

    private(set) var calls: [Call] = []

    func playEffect(_ cue: AudioCue) {
        calls.append(.playEffect(cue))
    }

    func setMusic(_ state: MusicPlaybackState) {
        calls.append(.setMusic(state))
    }

    func stopAllEffects() {
        calls.append(.stopAllEffects)
    }

    func stopAll() {
        calls.append(.stopAll)
    }

    func resetCalls() {
        calls.removeAll()
    }

    var playedEffects: [AudioCue] {
        calls.compactMap {
            if case .playEffect(let cue) = $0 { return cue }
            return nil
        }
    }

    var musicStates: [MusicPlaybackState] {
        calls.compactMap {
            if case .setMusic(let state) = $0 { return state }
            return nil
        }
    }
}
