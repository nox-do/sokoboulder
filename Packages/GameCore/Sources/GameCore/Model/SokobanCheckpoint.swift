/// File-independent semantic snapshot of movable Sokoban state.
///
/// Terrain and goals always come from the catalog ``SokobanLevel``. This type
/// captures only what a run file must restore: player, crates, counters, status.
/// Crates are sorted by ascending entity ID.
public struct SokobanCheckpoint: Equatable, Sendable {
    public let playerPosition: GridPosition
    /// Crate placements sorted by ``SokobanCratePlacement/id`` ascending.
    public let crates: [SokobanCratePlacement]
    public let moveCount: Int
    public let pushCount: Int
    public let status: PlayStatus

    public init(
        playerPosition: GridPosition,
        crates: [SokobanCratePlacement],
        moveCount: Int,
        pushCount: Int,
        status: PlayStatus
    ) {
        self.playerPosition = playerPosition
        self.crates = crates
        self.moveCount = moveCount
        self.pushCount = pushCount
        self.status = status
    }
}

/// One crate identity and position inside a ``SokobanCheckpoint``.
public struct SokobanCratePlacement: Equatable, Hashable, Sendable {
    public let id: EntityID
    public let position: GridPosition

    public init(id: EntityID, position: GridPosition) {
        self.id = id
        self.position = position
    }
}
