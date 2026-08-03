import GameCore

/// How the audio director should apply an ``AudioUpdate``.
enum AudioDelivery: Equatable, Sendable {
    case perform
    case synchronize
}

/// Non-authoritative context for music / theme alignment.
struct AudioContext: Equatable, Sendable {
    let game: AudioGameMode
    let levelID: String
    let status: PlayStatus

    init(game: AudioGameMode = .sokoban, levelID: String, status: PlayStatus) {
        self.game = game
        self.levelID = levelID
        self.status = status
    }
}

/// One ordered session→audio transition, paired with a ``RenderUpdate``.
struct AudioUpdate: Equatable, Sendable {
    let targetRevision: UInt64
    let context: AudioContext
    let events: [GameEvent]
    let delivery: AudioDelivery
}
