import Foundation
import GameCore
@testable import MacGameApp

/// Records playback calls for AudioDirector contract tests (no audio device).
@MainActor
final class SpyAudioPlaybackBackend: AudioPlaybackBackend {
    enum Call: Equatable, Sendable {
        case applyTheme(String)
        case playEffect(AudioCue)
        case setMusic(MusicPlaybackState, fadeOutDuration: TimeInterval)
        case stopAllEffects
        case stopAll
        case applyOutputSettings(AudioOutputSettings)
    }

    private(set) var calls: [Call] = []
    private(set) var lastOutputSettings: AudioOutputSettings?
    private(set) var lastThemeID: String?
    private(set) var lastMusicPath: String?

    func applyTheme(_ theme: AudioTheme) {
        lastThemeID = theme.id
        lastMusicPath = theme.musicPlayingPath
        calls.append(.applyTheme(theme.id))
    }

    func playEffect(_ cue: AudioCue) {
        calls.append(.playEffect(cue))
    }

    func setMusic(_ state: MusicPlaybackState, fadeOutDuration: TimeInterval) {
        calls.append(.setMusic(state, fadeOutDuration: fadeOutDuration))
    }

    func stopAllEffects() {
        calls.append(.stopAllEffects)
    }

    func stopAll() {
        calls.append(.stopAll)
    }

    func applyOutputSettings(_ settings: AudioOutputSettings) {
        lastOutputSettings = settings
        calls.append(.applyOutputSettings(settings))
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
            if case .setMusic(let state, fadeOutDuration: _) = $0 { return state }
            return nil
        }
    }

    var musicFadeDurations: [TimeInterval] {
        calls.compactMap {
            if case .setMusic(_, fadeOutDuration: let duration) = $0 { return duration }
            return nil
        }
    }
}
