/// Authoritative cave world state for one level run.
///
/// Construction and mutation are module-internal. App code receives states from
/// ``CaveRules`` and treats them as read-only values.
public struct CaveState: Equatable, Sendable {
    public internal(set) var grid: Grid<CaveCell>
    public internal(set) var player: CavePlayerState
    public let playerID: EntityID
    public internal(set) var status: PlayStatus
    public internal(set) var tick: UInt64
    public internal(set) var score: Int
    public internal(set) var collectedDiamonds: Int
    public let requiredDiamonds: Int
    public let diamondValue: Int
    public let extraDiamondValue: Int
    public internal(set) var remainingTicks: Int
    public internal(set) var nextEntityID: UInt64
    public let magicWallMillingTicks: Int
    public internal(set) var magicWallStatus: MagicWallStatus
    public internal(set) var rng: DeterministicRNG
    public let amoebaMaxCells: Int
    /// Ticks remaining in slow-growth mode once the clock has started; `0` = fast.
    public internal(set) var amoebaSlowTicksRemaining: Int
    /// BDCFF BD2: slow-growth clock starts on the first tick with a growth opportunity.
    public internal(set) var amoebaSlowGrowthStarted: Bool
    /// Amoeba cell count from the previous tick (BDCFF lag-1 oversize check).
    public internal(set) var amoebaCellCountLastTick: Int
    /// Whether the amoeba population had no growth opportunity last tick.
    public internal(set) var amoebaSuffocatedLastTick: Bool

    init(
        grid: Grid<CaveCell>,
        player: CavePlayerState,
        playerID: EntityID,
        status: PlayStatus,
        tick: UInt64,
        score: Int,
        collectedDiamonds: Int,
        requiredDiamonds: Int,
        diamondValue: Int,
        extraDiamondValue: Int,
        remainingTicks: Int,
        nextEntityID: UInt64,
        magicWallMillingTicks: Int,
        magicWallStatus: MagicWallStatus,
        rng: DeterministicRNG,
        amoebaMaxCells: Int,
        amoebaSlowTicksRemaining: Int,
        amoebaSlowGrowthStarted: Bool,
        amoebaCellCountLastTick: Int,
        amoebaSuffocatedLastTick: Bool
    ) {
        self.grid = grid
        self.player = player
        self.playerID = playerID
        self.status = status
        self.tick = tick
        self.score = score
        self.collectedDiamonds = collectedDiamonds
        self.requiredDiamonds = requiredDiamonds
        self.diamondValue = diamondValue
        self.extraDiamondValue = extraDiamondValue
        self.remainingTicks = remainingTicks
        self.nextEntityID = nextEntityID
        self.magicWallMillingTicks = magicWallMillingTicks
        self.magicWallStatus = magicWallStatus
        self.rng = rng
        self.amoebaMaxCells = amoebaMaxCells
        self.amoebaSlowTicksRemaining = amoebaSlowTicksRemaining
        self.amoebaSlowGrowthStarted = amoebaSlowGrowthStarted
        self.amoebaCellCountLastTick = amoebaCellCountLastTick
        self.amoebaSuffocatedLastTick = amoebaSuffocatedLastTick
    }

    public var playerRef: EntityRef {
        EntityRef(id: playerID, kind: .player)
    }

    public var isExitOpen: Bool {
        collectedDiamonds >= requiredDiamonds
    }

    func validateEssentials() throws(EngineFault) {
        guard score >= 0, collectedDiamonds >= 0, remainingTicks >= 0 else {
            throw .invariantViolated("Counters must be non-negative")
        }
        guard requiredDiamonds >= 0, diamondValue >= 0, extraDiamondValue >= 0 else {
            throw .invariantViolated("Level rule values must be non-negative")
        }
        guard amoebaMaxCells > 0, amoebaSlowTicksRemaining >= 0 else {
            throw .invariantViolated("Amoeba rule values must be positive / non-negative")
        }
        guard grid.width > 0, grid.height > 0 else {
            throw .invariantViolated("Grid must be non-empty")
        }
        guard nextEntityID >= 2 else {
            throw .invariantViolated("nextEntityID must be at least 2")
        }

        var seenIDs: Set<UInt64> = [playerID.rawValue]
        var exitCount = 0

        for row in 0..<grid.height {
            for column in 0..<grid.width {
                let position = GridPosition(column: column, row: row)
                let cell = grid[position]
                if case .exit = cell.terrain {
                    exitCount += 1
                }
                if let occupant = cell.occupant {
                    guard seenIDs.insert(occupant.id.rawValue).inserted else {
                        throw .invariantViolated("Duplicate entity ID \(occupant.id.rawValue)")
                    }
                    guard occupant.id.rawValue < nextEntityID else {
                        throw .invariantViolated("Occupant ID not below nextEntityID")
                    }
                }
            }
        }

        guard exitCount >= 1 else {
            throw .invariantViolated("Level has no exit")
        }

        switch player {
        case .alive(let position):
            guard grid.contains(position) else {
                throw .invariantViolated("Player outside grid")
            }
            let cell = grid[position]
            guard cell.isPlayerWalkableTerrain else {
                throw .invariantViolated("Player on non-walkable terrain")
            }
            guard cell.occupant == nil else {
                throw .invariantViolated("Living player overlaps an occupant")
            }
            guard status == .playing || status == .completed else {
                throw .invariantViolated("Alive player with unexpected status")
            }
        case .dead(let position):
            guard grid.contains(position) else {
                throw .invariantViolated("Death site outside grid")
            }
            guard status == .failed else {
                throw .invariantViolated("Dead player requires failed status")
            }
        }
    }
}
