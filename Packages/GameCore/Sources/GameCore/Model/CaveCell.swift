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
        case .void, .wall, .steelWall, .magicWall, .exit(.closed): false
        }
    }

    /// Empty floor space for gravity / push destinations (no dirt, no exit).
    public var isGravityEmptyTerrain: Bool {
        terrain == .floor
    }
}

/// Global magic-wall machine for the cave (BDCFF: not per-cell).
public enum MagicWallStatus: Equatable, Sendable {
    case dormant
    case active(remainingTicks: Int)
    case expired
}

public enum CaveTerrain: Equatable, Sendable {
    case void
    case floor
    case wall
    case steelWall
    /// Looks like brick; conversion uses ``CaveState/magicWallStatus``.
    case magicWall
    case dirt
    case exit(ExitState)
}

public enum CaveOccupant: Equatable, Sendable {
    case boulder(EntityID, motion: FallingState)
    case diamond(EntityID, motion: FallingState)
    case firefly(EntityID, heading: Direction)
    case butterfly(EntityID, heading: Direction)
    case amoeba(EntityID)

    public var id: EntityID {
        switch self {
        case .boulder(let id, _),
             .diamond(let id, _),
             .firefly(let id, _),
             .butterfly(let id, _),
             .amoeba(let id):
            id
        }
    }

    /// Gravity motion when this occupant falls/rolls; `nil` for enemies/amoeba.
    public var motion: FallingState? {
        switch self {
        case .boulder(_, let motion), .diamond(_, let motion): motion
        case .firefly, .butterfly, .amoeba: nil
        }
    }

    public var heading: Direction? {
        switch self {
        case .firefly(_, let heading), .butterfly(_, let heading): heading
        case .boulder, .diamond, .amoeba: nil
        }
    }

    public var entityKind: EntityKind {
        switch self {
        case .boulder: .boulder
        case .diamond: .diamond
        case .firefly: .firefly
        case .butterfly: .butterfly
        case .amoeba: .amoeba
        }
    }

    public var entityRef: EntityRef {
        EntityRef(id: id, kind: entityKind)
    }

    public var isEnemy: Bool {
        switch self {
        case .firefly, .butterfly: true
        case .boulder, .diamond, .amoeba: false
        }
    }

    public var isAmoeba: Bool {
        if case .amoeba = self { return true }
        return false
    }

    public var isGravityAffected: Bool {
        switch self {
        case .boulder, .diamond: true
        case .firefly, .butterfly, .amoeba: false
        }
    }

    public var explosionKind: CaveExplosionKind? {
        switch self {
        case .firefly: .destructive
        case .butterfly: .diamondGenerating
        case .boulder, .diamond, .amoeba: nil
        }
    }

    public func withMotion(_ motion: FallingState) -> CaveOccupant {
        switch self {
        case .boulder(let id, _): .boulder(id, motion: motion)
        case .diamond(let id, _): .diamond(id, motion: motion)
        case .firefly, .butterfly, .amoeba:
            preconditionFailure("Enemies/amoeba have no falling motion")
        }
    }

    /// Boulder ↔ diamond through an active magic wall; caller supplies a fresh id
    /// so presentation never reuses a stale kind on the same node.
    public func morphedThroughMagicWall(id: EntityID) -> CaveOccupant {
        switch self {
        case .boulder: .diamond(id, motion: .falling)
        case .diamond: .boulder(id, motion: .falling)
        case .firefly, .butterfly, .amoeba:
            preconditionFailure("Enemies/amoeba cannot pass a magic wall")
        }
    }

    public func withHeading(_ heading: Direction) -> CaveOccupant {
        switch self {
        case .firefly(let id, _): .firefly(id, heading: heading)
        case .butterfly(let id, _): .butterfly(id, heading: heading)
        case .boulder, .diamond, .amoeba:
            preconditionFailure("Gravity occupants/amoeba have no heading")
        }
    }

    /// Rocks and diamonds are round; enemies and amoeba are not.
    public var isRoundSupport: Bool {
        switch self {
        case .boulder, .diamond: true
        case .firefly, .butterfly, .amoeba: false
        }
    }
}

/// Living player position, or death site that no longer occupies the cell.
public enum CavePlayerState: Equatable, Sendable {
    case alive(at: GridPosition)
    case dead(at: GridPosition)
}
