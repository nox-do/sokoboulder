import Foundation

/// Compile-time fallbacks when JSON themes fail to load.
enum BuiltInAudioThemes {
    static var sokoban: AudioTheme {
        AudioTheme(
            id: AudioTheme.sokobanID,
            game: .sokoban,
            musicPlayingPath: "Audio/Music/sokoban-puzzling.mp3",
            cueResourcePaths: [
                .movementStep: "Audio/Effects/sokoban/movementStep.wav",
                .movementBlocked: "Audio/Effects/shared/movementBlocked.wav",
                .objectPushed: "Audio/Effects/sokoban/cratePushed.wav",
                .objectLanded: "Audio/Effects/shared/objectLanded.wav",
                .collectiblePickedUp: "Audio/Effects/sokoban/crateOnGoal.wav",
                .objectiveCompleted: "Audio/Effects/shared/levelCompleted.wav",
                .goalLeft: "Audio/Effects/sokoban/goalLeft.wav",
            ]
        )
    }

    static var cave: AudioTheme {
        AudioTheme(
            id: AudioTheme.caveID,
            game: .cave,
            musicPlayingPath: "Audio/Music/cave-wonder.mp3",
            cueResourcePaths: [
                .movementStep: "Audio/Effects/shared/movementStep.wav",
                .movementBlocked: "Audio/Effects/shared/movementBlocked.wav",
                .objectPushed: "Audio/Effects/boulderDash/boulderPushed.wav",
                .objectLanded: "Audio/Effects/shared/objectLanded.wav",
                .collectiblePickedUp: "Audio/Effects/boulderDash/diamondCollected.wav",
                .objectiveCompleted: "Audio/Effects/shared/levelCompleted.wav",
                .exitOpened: "Audio/Effects/shared/exitOpened.wav",
                .playerDied: "Audio/Effects/shared/playerDied.wav",
                .timeExpired: "Audio/Effects/shared/timeExpired.wav",
            ]
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
