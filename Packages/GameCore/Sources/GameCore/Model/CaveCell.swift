/// Motion of a gravity-affected cave occupant.
public enum FallingState: Equatable, Sendable {
    case resting
    case falling
}

/// Exit tile open/closed state.
public enum ExitState: Equatable, Sendable {
    case closed
    case open
}

/// One cave cell: immutable terrain plus optional movable occupant.
public struct CaveCell: Equatable, Sendable {
    public let terrain: CaveTerrain
    /// Mutable only inside GameCore so rule transitions keep invariants.
    public internal(set) var occupant: CaveOccupant?

    public init(terrain: CaveTerrain, occupant: CaveOccupant? = nil) {
        self.terrain = terrain
        self.occupant = occupant
    }

    /// Terrain the living player may enter (occupant rules apply separately).
    public var isPlayerWalkableTerrain: Bool {
        switch terrain {
        case .floor, .dirt, .exit(.open): true
        case .void, .wall, .steelWall, .exit(.closed): false
        }
    }

    /// Empty floor space for gravity / push destinations (no dirt, no exit).
    public var isGravityEmptyTerrain: Bool {
        terrain == .floor
    }
}

public enum CaveTerrain: Equatable, Sendable {
    case void
    case floor
    case wall
    case steelWall
    case dirt
    case exit(ExitState)
}

public enum CaveOccupant: Equatable, Sendable {
    case boulder(EntityID, motion: FallingState)
    case diamond(EntityID, motion: FallingState)

    public var id: EntityID {
        switch self {
        case .boulder(let id, _), .diamond(let id, _): id
        }
    }

    public var motion: FallingState {
        switch self {
        case .boulder(_, let motion), .diamond(_, let motion): motion
        }
    }

    public var entityKind: EntityKind {
        switch self {
        case .boulder: .boulder
        case .diamond: .diamond
        }
    }

    public var entityRef: EntityRef {
        EntityRef(id: id, kind: entityKind)
    }

    public func withMotion(_ motion: FallingState) -> CaveOccupant {
        switch self {
        case .boulder(let id, _): .boulder(id, motion: motion)
        case .diamond(let id, _): .diamond(id, motion: motion)
        }
    }

    public var isRoundSupport: Bool {
        true
    }
}

/// Living player position, or death site that no longer occupies the cell.
public enum CavePlayerState: Equatable, Sendable {
    case alive(at: GridPosition)
    case dead(at: GridPosition)
}
