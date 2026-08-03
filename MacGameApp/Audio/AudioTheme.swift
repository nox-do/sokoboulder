import Foundation

/// Which game an audio theme belongs to. Cue/theme selection is mode-driven;
/// background tracks may additionally be chosen in settings via ``MusicTrack``.
enum AudioGameMode: String, Equatable, Codable, Sendable, CaseIterable {
    case sokoban
    case cave
}

/// Runtime audio theme: music path + optional file-backed cue paths.
///
/// Missing or unloadable assets degrade to silence (music) or procedural tones (cues).
/// Settings may override ``musicPlayingPath`` through the music-track catalog.
struct AudioTheme: Equatable, Sendable {
    static let sokobanID = "audio.sokoban"
    static let caveID = "audio.cave"
    static let knownIDs = [sokobanID, caveID]

    let id: String
    let game: AudioGameMode
    /// Bundle-relative path for `.playing` music; `nil` means silence.
    let musicPlayingPath: String?
    /// File-backed cues only. Absent keys use the procedural fallback.
    let cueResourcePaths: [AudioCue: String]

    func resourcePath(for cue: AudioCue) -> String? {
        cueResourcePaths[cue]
    }

    func replacingMusicPlayingPath(_ path: String?) -> AudioTheme {
        AudioTheme(
            id: id,
            game: game,
            musicPlayingPath: path,
            cueResourcePaths: cueResourcePaths
        )
    }
}
