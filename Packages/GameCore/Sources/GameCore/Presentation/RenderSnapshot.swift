/// Presentation-facing terrain kind used in ``RenderSnapshot``.
///
/// Independent of authoritative cell types so the renderer never needs
/// ``SokobanState`` or ``CaveState``.
public enum RenderTerrain: Equatable, Sendable {
    case void
    case floor
    case wall
    case steelWall
    case magicWall
    case magicWallActive
    case dirt
    case goal
    case exitClosed
    case exitOpen
}

/// One projected grid cell: terrain only. Occupants live in ``RenderEntity``.
public struct RenderCell: Equatable, Sendable {
    public let terrain: RenderTerrain

    public init(terrain: RenderTerrain) {
        self.terrain = terrain
    }
}

/// Movable entity projection for rendering and animation identity.
public struct RenderEntity: Equatable, Sendable {
    public let ref: EntityRef
    public let position: GridPosition

    public init(ref: EntityRef, position: GridPosition) {
        self.ref = ref
        self.position = position
    }
}

/// Game-specific counters; cave time and score never masquerade as Sokoban moves/pushes.
public enum PlayMetrics: Equatable, Sendable {
    case sokoban(SokobanMetrics)
    case cave(CaveMetrics)

    public var sokoban: SokobanMetrics? {
        if case .sokoban(let metrics) = self { return metrics }
        return nil
    }

    public var cave: CaveMetrics? {
        if case .cave(let metrics) = self { return metrics }
        return nil
    }
}

public struct SokobanMetrics: Equatable, Sendable {
    public let moveCount: Int
    public let pushCount: Int
    public let completedGoalCount: Int
    public let totalGoalCount: Int

    public init(moveCount: Int, pushCount: Int, completedGoalCount: Int, totalGoalCount: Int) {
        precondition(moveCount >= 0 && pushCount >= 0)
        precondition(completedGoalCount >= 0 && completedGoalCount <= totalGoalCount)
        self.moveCount = moveCount
        self.pushCount = pushCount
        self.completedGoalCount = completedGoalCount
        self.totalGoalCount = totalGoalCount
    }
}

public struct CaveMetrics: Equatable, Sendable {
    public let collectedDiamonds: Int
    public let requiredDiamonds: Int
    public let remainingTicks: Int
    public let score: Int

    public init(collectedDiamonds: Int, requiredDiamonds: Int, remainingTicks: Int, score: Int) {
        precondition(collectedDiamonds >= 0 && requiredDiamonds >= 0 && remainingTicks >= 0 && score >= 0)
        self.collectedDiamonds = collectedDiamonds
        self.requiredDiamonds = requiredDiamonds
        self.remainingTicks = remainingTicks
        self.score = score
    }
}

/// Immutable presentation projection of a playable board.
///
/// Cells are stored flat in row-major order: `index = row * width + column`.
/// Model origin `(0, 0)` is top-left; SpriteKit Y-flipping belongs in the renderer.
public struct RenderSnapshot: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let cells: [RenderCell]
    /// Non-player movable entities (Sokoban crates), stable for the run.
    public let entities: [RenderEntity]
    public let player: RenderEntity
    public let metrics: PlayMetrics
    public let status: PlayStatus

    public init(
        width: Int,
        height: Int,
        cells: [RenderCell],
        entities: [RenderEntity],
        player: RenderEntity,
        metrics: PlayMetrics,
        status: PlayStatus
    ) {
        precondition(width >= 0, "RenderSnapshot width must be non-negative")
        precondition(height >= 0, "RenderSnapshot height must be non-negative")
        precondition(
            cells.count == width * height,
            "RenderSnapshot cells.count must equal width * height"
        )
        self.width = width
        self.height = height
        self.cells = cells
        self.entities = entities
        self.player = player
        self.metrics = metrics
        self.status = status
    }

    /// Whether `position` lies inside the snapshot bounds.
    public func contains(_ position: GridPosition) -> Bool {
        position.column >= 0
            && position.row >= 0
            && position.column < width
            && position.row < height
    }

    /// Row-major index for `position`, or `nil` when out of bounds.
    public func index(of position: GridPosition) -> Int? {
        guard contains(position) else { return nil }
        return position.row * width + position.column
    }

    /// Safe cell lookup; `nil` outside the board.
    public func cell(at position: GridPosition) -> RenderCell? {
        guard let index = index(of: position) else { return nil }
        return cells[index]
    }
}

extension RenderSnapshot {
    /// Projects authoritative Sokoban state into a renderer-safe snapshot.
    public static func project(_ state: SokobanState) -> RenderSnapshot {
        let width = state.grid.width
        let height = state.grid.height
        var cells: [RenderCell] = []
        cells.reserveCapacity(width * height)
        var entities: [RenderEntity] = []

        for row in 0..<height {
            for column in 0..<width {
                let position = GridPosition(column: column, row: row)
                let cell = state.grid[position]
                cells.append(RenderCell(terrain: RenderTerrain(cell.terrain)))
                if case .crate(let id) = cell.occupant {
                    entities.append(
                        RenderEntity(
                            ref: EntityRef(id: id, kind: .crate),
                            position: position
                        )
                    )
                }
            }
        }

        return RenderSnapshot(
            width: width,
            height: height,
            cells: cells,
            entities: entities,
            player: RenderEntity(ref: state.playerRef, position: state.playerPosition),
            metrics: .sokoban(
                SokobanMetrics(
                    moveCount: state.moveCount,
                    pushCount: state.pushCount,
                    completedGoalCount: state.completedGoalCount,
                    totalGoalCount: state.goalCount
                )),
            status: state.status
        )
    }

    /// Projects authoritative cave state, including the unchanged diamond requirement.
    public static func project(_ state: CaveState) -> RenderSnapshot {
        let width = state.grid.width
        let height = state.grid.height
        var cells: [RenderCell] = []
        cells.reserveCapacity(width * height)
        var entities: [RenderEntity] = []

        for row in 0..<height {
            for column in 0..<width {
                let position = GridPosition(column: column, row: row)
                let cell = state.grid[position]
                cells.append(
                    RenderCell(terrain: RenderTerrain(cell.terrain, magicWall: state.magicWallStatus))
                )
                if let occupant = cell.occupant {
                    entities.append(
                        RenderEntity(ref: occupant.entityRef, position: position)
                    )
                }
            }
        }

        let playerPosition: GridPosition
        switch state.player {
        case .alive(let position), .dead(let position):
            playerPosition = position
        }

        return RenderSnapshot(
            width: width,
            height: height,
            cells: cells,
            entities: entities,
            player: RenderEntity(ref: state.playerRef, position: playerPosition),
            metrics: .cave(
                CaveMetrics(
                    collectedDiamonds: state.collectedDiamonds,
                    requiredDiamonds: state.requiredDiamonds,
                    remainingTicks: state.remainingTicks,
                    score: state.score
                )),
            status: state.status
        )
    }
}

extension RenderTerrain {
    fileprivate init(_ terrain: SokobanTerrain) {
        switch terrain {
        case .void: self = .void
        case .floor: self = .floor
        case .wall: self = .wall
        case .goal: self = .goal
        }
    }

    fileprivate init(_ terrain: CaveTerrain, magicWall status: MagicWallStatus) {
        switch terrain {
        case .void: self = .void
        case .floor: self = .floor
        case .wall: self = .wall
        case .steelWall: self = .steelWall
        case .magicWall:
            if case .active = status {
                self = .magicWallActive
            } else {
                self = .magicWall
            }
        case .dirt: self = .dirt
        case .exit(.closed): self = .exitClosed
        case .exit(.open): self = .exitOpen
        }
    }
}
