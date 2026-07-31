import GameCore

/// How the audio director should apply an ``AudioUpdate``.
enum AudioDelivery: Equatable, Sendable {
    case perform
    case synchronize
}

/// Non-authoritative context for music / pause alignment.
struct AudioContext: Equatable, Sendable {
    let levelID: String
    let status: PlayStatus
}

/// One ordered session→audio transition, paired with a ``RenderUpdate``.
struct AudioUpdate: Equatable, Sendable {
    let targetRevision: UInt64
    let context: AudioContext
    let events: [GameEvent]
    let delivery: AudioDelivery
}
