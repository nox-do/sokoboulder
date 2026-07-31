/// One Sokoban cell: immutable terrain plus optional crate occupant.
public struct SokobanCell: Equatable, Sendable {
    public let terrain: SokobanTerrain
    /// Mutable only inside GameCore so rule transitions keep invariants.
    public internal(set) var occupant: SokobanOccupant?

    public init(terrain: SokobanTerrain, occupant: SokobanOccupant? = nil) {
        self.terrain = terrain
        self.occupant = occupant
    }

    /// Whether the player or a crate may enter this cell's terrain.
    public var isWalkable: Bool {
        switch terrain {
        case .floor, .goal: true
        case .void, .wall: false
        }
    }

    public var isGoal: Bool {
        terrain == .goal
    }
}

public enum SokobanTerrain: Equatable, Sendable {
    case void
    case floor
    case wall
    case goal
}

public enum SokobanOccupant: Equatable, Sendable {
    case crate(EntityID)
}
