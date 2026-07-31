/// Authoritative Sokoban world state for one level run.
///
/// Construction and mutation are module-internal. App code receives states from
/// ``SokobanRules`` and treats them as read-only values.
public struct SokobanState: Equatable, Sendable {
    public internal(set) var grid: Grid<SokobanCell>
    public internal(set) var playerPosition: GridPosition
    /// Deterministic player identity for ``GameEvent/entityMoved`` (and later rendering).
    public let playerID: EntityID
    public internal(set) var status: PlayStatus
    public internal(set) var moveCount: Int
    public internal(set) var pushCount: Int

    init(
        grid: Grid<SokobanCell>,
        playerPosition: GridPosition,
        playerID: EntityID,
        status: PlayStatus,
        moveCount: Int,
        pushCount: Int
    ) {
        self.grid = grid
        self.playerPosition = playerPosition
        self.playerID = playerID
        self.status = status
        self.moveCount = moveCount
        self.pushCount = pushCount
    }

    public var playerRef: EntityRef {
        EntityRef(id: playerID, kind: .player)
    }

    public var goalCount: Int {
        var count = 0
        for row in 0..<grid.height {
            for column in 0..<grid.width {
                if grid[GridPosition(column: column, row: row)].isGoal {
                    count += 1
                }
            }
        }
        return count
    }

    /// Number of crates currently sitting on goal terrain.
    public var completedGoalCount: Int {
        var count = 0
        for row in 0..<grid.height {
            for column in 0..<grid.width {
                let position = GridPosition(column: column, row: row)
                let cell = grid[position]
                if cell.isGoal, case .crate = cell.occupant {
                    count += 1
                }
            }
        }
        return count
    }

    public var allGoalsCompleted: Bool {
        goalCount > 0 && completedGoalCount == goalCount
    }

    /// Release-safe essential invariants checked by public rule transitions.
    func validateEssentials() throws(EngineFault) {
        guard moveCount >= 0, pushCount >= 0 else {
            throw .invariantViolated("Counters must be non-negative")
        }
        guard pushCount <= moveCount else {
            throw .invariantViolated("pushCount cannot exceed moveCount")
        }
        guard grid.width > 0, grid.height > 0 else {
            throw .invariantViolated("Grid must be non-empty")
        }
        guard grid.contains(playerPosition) else {
            throw .invariantViolated("Player outside grid")
        }

        let playerCell = grid[playerPosition]
        guard playerCell.isWalkable else {
            throw .invariantViolated("Player on non-walkable terrain")
        }
        guard playerCell.occupant == nil else {
            throw .invariantViolated("Player overlaps a crate")
        }

        var seenIDs: Set<UInt64> = [playerID.rawValue]
        var crateCount = 0
        var goals = 0

        for row in 0..<grid.height {
            for column in 0..<grid.width {
                let position = GridPosition(column: column, row: row)
                let cell = grid[position]
                if cell.isGoal {
                    goals += 1
                }
                if let occupant = cell.occupant {
                    guard cell.isWalkable else {
                        throw .invariantViolated("Crate on non-walkable terrain at \(position)")
                    }
                    guard case .crate(let id) = occupant else {
                        throw .invariantViolated("Unknown occupant at \(position)")
                    }
                    guard seenIDs.insert(id.rawValue).inserted else {
                        throw .invariantViolated("Duplicate entity ID \(id.rawValue)")
                    }
                    crateCount += 1
                }
            }
        }

        guard goals > 0 else {
            throw .invariantViolated("Level has no goals")
        }
        guard crateCount == goals else {
            throw .invariantViolated(
                "Crate count \(crateCount) does not match goal count \(goals)"
            )
        }

        switch status {
        case .playing:
            guard !allGoalsCompleted else {
                throw .invariantViolated("Playing status with all goals already filled")
            }
        case .completed:
            guard allGoalsCompleted else {
                throw .invariantViolated("Completed status without all goals filled")
            }
        case .failed:
            throw .invariantViolated("Sokoban does not use failed status")
        }
    }
}
