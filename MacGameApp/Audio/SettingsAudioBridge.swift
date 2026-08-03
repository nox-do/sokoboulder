import Foundation

/// Pushes settings snapshot values into ``AudioDirector`` (volumes, mute, track IDs).
@MainActor
struct SettingsAudioBridge {
    let audioDirector: AudioDirector
    let settingsStore: AppSettingsStore

    func applyFromStore() {
        audioDirector.applyOutputSettings(.from(settings: settingsStore.snapshot))
        audioDirector.applyMusicTrackID(settingsStore.sokobanMusicTrackID, for: .sokoban)
        audioDirector.applyMusicTrackID(settingsStore.caveMusicTrackID, for: .cave)
    }
}
