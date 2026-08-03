/// Resolved cave input for one simulation tick.
public enum CaveInput: Equatable, Sendable {
    case move(Direction)
    case wait
}

/// Level definition for cave start (ASCII tests and later JSON).
public struct CaveLevel: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let terrain: Grid<CaveTerrain>
    public let playerStart: GridPosition
    /// Occupant starts without motion (always resting at start).
    public let occupantStarts: [CaveOccupantStart]
    public let requiredDiamonds: Int
    public let timeLimitTicks: Int
    public let diamondValue: Int
    public let extraDiamondValue: Int

    public init(
        width: Int,
        height: Int,
        terrain: Grid<CaveTerrain>,
        playerStart: GridPosition,
        occupantStarts: [CaveOccupantStart],
        requiredDiamonds: Int,
        timeLimitTicks: Int,
        diamondValue: Int = 10,
        extraDiamondValue: Int = 15
    ) {
        self.width = width
        self.height = height
        self.terrain = terrain
        self.playerStart = playerStart
        self.occupantStarts = occupantStarts
        self.requiredDiamonds = requiredDiamonds
        self.timeLimitTicks = timeLimitTicks
        self.diamondValue = diamondValue
        self.extraDiamondValue = extraDiamondValue
    }
}

public struct CaveOccupantStart: Equatable, Sendable {
    public let position: GridPosition
    public let kind: CaveOccupantKind

    public init(position: GridPosition, kind: CaveOccupantKind) {
        self.position = position
        self.kind = kind
    }
}

public enum CaveOccupantKind: Equatable, Sendable {
    case boulder
    case diamond
}
