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
    public let magicWallMillingTicks: Int

    public init(
        width: Int,
        height: Int,
        terrain: Grid<CaveTerrain>,
        playerStart: GridPosition,
        occupantStarts: [CaveOccupantStart],
        requiredDiamonds: Int,
        timeLimitTicks: Int,
        diamondValue: Int = 10,
        extraDiamondValue: Int = 15,
        magicWallMillingTicks: Int = CaveLevelRulesV1.defaultMagicWallMillingTicks
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
        self.magicWallMillingTicks = magicWallMillingTicks
    }
}

public struct CaveOccupantStart: Equatable, Sendable {
    public let position: GridPosition
    public let kind: CaveOccupantKind
    /// Initial facing for enemies; ignored for boulder/diamond.
    public let heading: Direction

    public init(
        position: GridPosition,
        kind: CaveOccupantKind,
        heading: Direction = .left
    ) {
        self.position = position
        self.kind = kind
        self.heading = heading
    }
}

public enum CaveOccupantKind: Equatable, Sendable {
    case boulder
    case diamond
    case firefly
    case butterfly
}

/// Explosion effect produced by enemies (ADR 0005).
public enum CaveExplosionKind: Equatable, Sendable {
    case destructive
    case diamondGenerating
}
