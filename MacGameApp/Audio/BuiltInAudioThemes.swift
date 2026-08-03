import Foundation

/// Built-in audio themes used when JSON is missing or incomplete.
enum BuiltInAudioThemes {
    static var sokoban: AudioTheme {
        AudioTheme(
            id: AudioTheme.sokobanID,
            game: .sokoban,
            musicPlayingPath: "Audio/Music/sokoban-puzzling.mp3",
            cueResourcePaths: [
                .step: "Audio/Effects/sokoban-step.wav",
                .blocked: "Audio/Effects/sokoban-blocked.wav",
                .cratePushed: "Audio/Effects/sokoban-crate-pushed.wav",
                .goalEntered: "Audio/Effects/sokoban-goal-entered.wav",
                .goalLeft: "Audio/Effects/sokoban-goal-left.wav",
                .levelCompleted: "Audio/Jingles/sokoban-level-completed.wav",
            ]
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
