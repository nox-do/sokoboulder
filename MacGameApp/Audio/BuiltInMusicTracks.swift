import Foundation

/// Built-in music tracks used when JSON is missing or incomplete.
enum BuiltInMusicTracks {
    static var puzzling: MusicTrack {
        MusicTrack(
            id: MusicTrack.puzzlingID,
            game: .sokoban,
            displayNameID: "music.sokoban.puzzling.name",
            resourcePath: "Audio/Music/sokoban-puzzling.mp3",
            credit: MusicTrackCredit(
                title: "Puzzling",
                author: "Ruskerdax",
                sourceURL: "https://opengameart.org/content/puzzling",
                license: "CC0 1.0",
                attributionNotice: nil
            )
        )
    }

    static var prelude: MusicTrack {
        MusicTrack(
            id: MusicTrack.preludeID,
            game: .sokoban,
            displayNameID: "music.sokoban.prelude.name",
            resourcePath: "Audio/Music/sokoban-prelude.mp3",
            credit: MusicTrackCredit(
                title: "Prelude (Story)",
                author: "Alexandr Zhelanov",
                sourceURL: "https://opengameart.org/content/old-music",
                license: "CC-BY 3.0",
                attributionNotice: "Alexandr Zhelanov, https://soundcloud.com/alexandr-zhelanov"
            )
        )
    }

    static func fallback(id: String) -> MusicTrack {
        switch id {
        case MusicTrack.preludeID:
            return prelude
        default:
            return puzzling
        }
    }

    static func allFallbacks() -> [MusicTrack] {
        [puzzling, prelude]
    }
}
