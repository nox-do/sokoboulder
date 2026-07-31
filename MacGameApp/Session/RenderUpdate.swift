import GameCore

/// How the renderer should apply a ``RenderUpdate``.
enum RenderDelivery: Equatable, Sendable {
    case animate
    case hardResync
}

/// One ordered session→renderer transition.
///
/// Invariant: `targetRevision == baseRevision + 1` for every emitted update.
struct RenderUpdate: Equatable, Sendable {
    let baseRevision: UInt64
    let targetRevision: UInt64
    let snapshot: RenderSnapshot
    let events: [GameEvent]
    let delivery: RenderDelivery

    init(
        baseRevision: UInt64,
        targetRevision: UInt64,
        snapshot: RenderSnapshot,
        events: [GameEvent],
        delivery: RenderDelivery
    ) {
        precondition(targetRevision == baseRevision + 1)
        self.baseRevision = baseRevision
        self.targetRevision = targetRevision
        self.snapshot = snapshot
        self.events = events
        self.delivery = delivery
    }
}
