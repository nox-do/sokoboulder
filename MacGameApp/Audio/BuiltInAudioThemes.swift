import Foundation

/// Built-in audio themes used when JSON is missing or incomplete.
enum BuiltInAudioThemes {
    static var sokoban: AudioTheme {
        AudioTheme(
            id: AudioTheme.sokobanID,
            game: .sokoban,
            musicPlayingPath: "Audio/Music/sokoban-puzzling.mp3",
            cueResourcePaths: [:]
        )
    }

    static var cave: AudioTheme {
        AudioTheme(
            id: AudioTheme.caveID,
            game: .cave,
            musicPlayingPath: nil,
            cueResourcePaths: [:]
        )
    }

    static func fallback(id: String) -> AudioTheme {
        switch id {
        case AudioTheme.caveID:
            return cave
        default:
            return sokoban
        }
    }

    static func allFallbacks() -> [AudioTheme] {
        [sokoban, cave]
    }
}
