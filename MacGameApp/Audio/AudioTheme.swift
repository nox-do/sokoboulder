import Foundation

/// Which game an audio theme belongs to. Selection is mode-driven, not a settings picker.
enum AudioGameMode: String, Equatable, Codable, Sendable, CaseIterable {
    case sokoban
    case cave
}

/// Runtime audio theme: music path + optional file-backed cue paths.
///
/// Missing or unloadable assets degrade to silence (music) or procedural tones (cues).
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
}
