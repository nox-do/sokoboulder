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

    static var caveWonder: MusicTrack {
        MusicTrack(
            id: MusicTrack.caveWonderID,
            game: .cave,
            displayNameID: "music.cave.wonder.name",
            resourcePath: "Audio/Music/cave-wonder.mp3",
            credit: MusicTrackCredit(
                title: "Cave Wonder",
                author: "tapatilorenzo",
                sourceURL: "https://opengameart.org/content/2-midi-cave-songs-cave-wonder-tinkering-cave",
                license: "CC0 1.0",
                attributionNotice: nil
            )
        )
    }

    static var caveTinkering: MusicTrack {
        MusicTrack(
            id: MusicTrack.caveTinkeringID,
            game: .cave,
            displayNameID: "music.cave.tinkering.name",
            resourcePath: "Audio/Music/cave-tinkering.mp3",
            credit: MusicTrackCredit(
                title: "Tinkering Cave",
                author: "tapatilorenzo",
                sourceURL: "https://opengameart.org/content/2-midi-cave-songs-cave-wonder-tinkering-cave",
                license: "CC0 1.0",
                attributionNotice: nil
            )
        )
    }

    static func fallback(id: String) -> MusicTrack {
        switch id {
        case MusicTrack.preludeID:
            return prelude
        case MusicTrack.caveWonderID:
            return caveWonder
        case MusicTrack.caveTinkeringID:
            return caveTinkering
        default:
            return puzzling
        }
    }

    static func allFallbacks() -> [MusicTrack] {
        [puzzling, prelude, caveWonder, caveTinkering]
    }

    static func defaultTrackIDs() -> [AudioGameMode: String] {
        [
            .sokoban: MusicTrack.puzzlingID,
            .cave: MusicTrack.caveWonderID,
        ]
    }
}
