/// Deterministic Sokoban rule engine.
///
/// Accepts only validated ``SokobanLevel`` values. Crate and player entity IDs
/// are assigned in ``start(level:)`` so two starts of the same level produce
/// identical states. Public transitions check essential invariants in all builds.
public struct SokobanRules: Sendable {
    /// Bump only when replay or checkpoint semantics change — not for refactors,
    /// UI, or rendering.
    public static let ruleVersion: Int = 1

    public init() {}

    /// Builds the initial run state. Crate IDs are assigned in row-major order
    /// of crate positions; the player receives ``EntityID`` `1` and crates
    /// continue from `2`.
    ///
    /// Already-solved levels start with ``PlayStatus/completed``.
    public func start(level: SokobanLevel) throws(EngineFault) -> SokobanState {
        try validateLevel(level)

        let playerID = EntityID(1)
        let cratePositions = Set(level.crateStarts)

        var cells: [SokobanCell] = []
        cells.reserveCapacity(level.width * level.height)
        var nextCrateID: UInt64 = 2

        for row in 0..<level.height {
            for column in 0..<level.width {
                let position = GridPosition(column: column, row: row)
                let terrain = level.terrain[position]
                let occupant: SokobanOccupant?
                if cratePositions.contains(position) {
                    occupant = .crate(EntityID(nextCrateID))
                    nextCrateID += 1
                } else {
                    occupant = nil
                }
                cells.append(SokobanCell(terrain: terrain, occupant: occupant))
            }
        }

        let grid = Grid(width: level.width, height: level.height, cells: cells)
        var state = SokobanState(
            grid: grid,
            playerPosition: level.playerStart,
            playerID: playerID,
            status: .playing,
            moveCount: 0,
            pushCount: 0
        )

        if state.allGoalsCompleted {
            state.status = .completed
        }

        try state.validateEssentials()
        return state
    }

    /// Extracts a semantic checkpoint from an authoritative state.
    ///
    /// Crates are sorted by ascending entity ID. Does not validate against a level;
    /// pair with ``restore(level:checkpoint:)`` for that.
    public func checkpoint(from state: SokobanState) -> SokobanCheckpoint {
        var crates: [SokobanCratePlacement] = []
        for row in 0..<state.grid.height {
            for column in 0..<state.grid.width {
                let position = GridPosition(column: column, row: row)
                if case .crate(let id)? = state.grid[position].occupant {
                    crates.append(SokobanCratePlacement(id: id, position: position))
                }
            }
        }
        crates.sort { $0.id.rawValue < $1.id.rawValue }
        return SokobanCheckpoint(
            playerPosition: state.playerPosition,
            crates: crates,
            moveCount: state.moveCount,
            pushCount: state.pushCount,
            status: state.status
        )
    }

    /// Rebuilds a ``SokobanState`` from level terrain and a semantic checkpoint.
    ///
    /// Validates crate IDs against the canonical set `2...(crateCount+1)`,
    /// uniqueness, walkability, counters, and status/goal consistency.
    public func restore(
        level: SokobanLevel,
        checkpoint: SokobanCheckpoint
    ) throws(EngineFault) -> SokobanState {
        try validateLevel(level)
        try validateCheckpoint(checkpoint, against: level)

        var cells: [SokobanCell] = []
        cells.reserveCapacity(level.width * level.height)
        var occupantByPosition: [GridPosition: EntityID] = [:]
        for crate in checkpoint.crates {
            occupantByPosition[crate.position] = crate.id
        }

        for row in 0..<level.height {
            for column in 0..<level.width {
                let position = GridPosition(column: column, row: row)
                let terrain = level.terrain[position]
                let occupant: SokobanOccupant?
                if let id = occupantByPosition[position] {
                    occupant = .crate(id)
                } else {
                    occupant = nil
                }
                cells.append(SokobanCell(terrain: terrain, occupant: occupant))
            }
        }

        let state = SokobanState(
            grid: Grid(width: level.width, height: level.height, cells: cells),
            playerPosition: checkpoint.playerPosition,
            playerID: EntityID(1),
            status: checkpoint.status,
            moveCount: checkpoint.moveCount,
            pushCount: checkpoint.pushCount
        )
        try state.validateEssentials()
        return state
    }

    /// Applies one movement attempt.
    ///
    /// - Essential pre- and postconditions are checked in all builds.
    /// - Input while ``PlayStatus/completed`` returns the same state, no events,
    ///   and ``StepOutcome/blocked`` — not an ``EngineFault``.
    /// - ``PlayStatus/failed`` is not used by Sokoban and fails
    ///   ``SokobanState/validateEssentials()`` with ``EngineFault``.
    /// - Blocked moves leave counters and positions unchanged and emit
    ///   ``GameEvent/movementBlocked``.
    public func move(
        _ direction: Direction,
        in state: SokobanState
    ) throws(EngineFault) -> Transition<SokobanState> {
        try state.validateEssentials()

        if state.status != .playing {
            return Transition(state: state, events: [], outcome: .blocked)
        }

        let from = state.playerPosition
        let target = from.neighbor(in: direction)

        let transition: Transition<SokobanState>
        if !state.grid.contains(target) {
            transition = blocked(state, at: target)
        } else {
            let targetCell = state.grid[target]
            if !targetCell.isWalkable {
                transition = blocked(state, at: target)
            } else if case .crate(let crateID)? = targetCell.occupant {
                transition = try pushCrate(
                    id: crateID,
                    from: from,
                    cratePosition: target,
                    direction: direction,
                    in: state
                )
            } else {
                transition = try movePlayer(
                    from: from,
                    to: target,
                    in: state,
                    didPush: false,
                    eventsPrefix: []
                )
            }
        }

        try transition.state.validateEssentials()
        return transition
    }

    private func validateCheckpoint(
        _ checkpoint: SokobanCheckpoint,
        against level: SokobanLevel
    ) throws(EngineFault) {
        guard checkpoint.moveCount >= 0, checkpoint.pushCount >= 0 else {
            throw .invariantViolated("Checkpoint counters must be non-negative")
        }
        guard checkpoint.pushCount <= checkpoint.moveCount else {
            throw .invariantViolated("Checkpoint pushCount cannot exceed moveCount")
        }

        switch checkpoint.status {
        case .playing, .completed:
            break
        case .failed:
            throw .invariantViolated("Sokoban checkpoints do not use failed status")
        }

        let expectedIDs: [UInt64] = (0..<level.crateStarts.count).map { UInt64($0 + 2) }
        let sortedCrates = checkpoint.crates.sorted { $0.id.rawValue < $1.id.rawValue }
        guard sortedCrates.map(\.id.rawValue) == checkpoint.crates.map(\.id.rawValue) else {
            throw .invariantViolated("Checkpoint crates must be sorted by ascending ID")
        }
        guard sortedCrates.map(\.id.rawValue) == expectedIDs else {
            throw .invariantViolated(
                "Checkpoint crate IDs must be exactly the canonical set 2...\(level.crateStarts.count + 1)"
            )
        }

        guard level.terrain.contains(checkpoint.playerPosition) else {
            throw .invariantViolated("Checkpoint player outside grid")
        }
        let playerTerrain = level.terrain[checkpoint.playerPosition]
        guard playerTerrain == .floor || playerTerrain == .goal else {
            throw .invariantViolated("Checkpoint player on non-walkable terrain")
        }

        var seenPositions: Set<GridPosition> = [checkpoint.playerPosition]
        var cratesOnGoals = 0
        var goalCount = 0
        for row in 0..<level.height {
            for column in 0..<level.width {
                if level.terrain[GridPosition(column: column, row: row)] == .goal {
                    goalCount += 1
                }
            }
        }

        for crate in sortedCrates {
            guard level.terrain.contains(crate.position) else {
                throw .invariantViolated("Checkpoint crate outside grid at \(crate.position)")
            }
            let terrain = level.terrain[crate.position]
            guard terrain == .floor || terrain == .goal else {
                throw .invariantViolated("Checkpoint crate on non-walkable terrain at \(crate.position)")
            }
            guard seenPositions.insert(crate.position).inserted else {
                throw .invariantViolated("Checkpoint has overlapping entities at \(crate.position)")
            }
            if terrain == .goal {
                cratesOnGoals += 1
            }
        }

        let allGoalsFilled = goalCount > 0 && cratesOnGoals == goalCount
        switch checkpoint.status {
        case .playing:
            guard !allGoalsFilled else {
                throw .invariantViolated("Playing checkpoint with all goals filled")
            }
        case .completed:
            guard allGoalsFilled else {
                throw .invariantViolated("Completed checkpoint without all goals filled")
            }
        case .failed:
            throw .invariantViolated("Sokoban checkpoints do not use failed status")
        }
    }

    private func validateLevel(_ level: SokobanLevel) throws(EngineFault) {
        guard level.width > 0, level.height > 0 else {
            throw .invariantViolated("Level must be non-empty")
        }

        guard level.terrain.contains(level.playerStart) else {
            throw .invariantViolated("Player start outside grid")
        }

        let playerTerrain = level.terrain[level.playerStart]
        guard playerTerrain == .floor || playerTerrain == .goal else {
            throw .invariantViolated("Player start is not walkable")
        }

        var goals = 0
        for row in 0..<level.height {
            for column in 0..<level.width {
                if level.terrain[GridPosition(column: column, row: row)] == .goal {
                    goals += 1
                }
            }
        }
        guard goals > 0 else {
            throw .invariantViolated("Level has no goals")
        }
        guard level.crateStarts.count == goals else {
            throw .invariantViolated(
                "Crate count \(level.crateStarts.count) does not match goal count \(goals)"
            )
        }

        var seen = Set<GridPosition>()
        var previous: GridPosition?
        for position in level.crateStarts {
            guard level.terrain.contains(position) else {
                throw .invariantViolated("Crate start outside grid at \(position)")
            }
            let terrain = level.terrain[position]
            guard terrain == .floor || terrain == .goal else {
                throw .invariantViolated("Crate start on non-walkable terrain at \(position)")
            }
            guard position != level.playerStart else {
                throw .invariantViolated("Crate overlaps player start")
            }
            guard seen.insert(position).inserted else {
                throw .invariantViolated("Duplicate crate start at \(position)")
            }
            if let previous {
                let ordered =
                    previous.row < position.row
                    || (previous.row == position.row && previous.column < position.column)
                guard ordered else {
                    throw .invariantViolated("crateStarts are not in row-major order")
                }
            }
            previous = position
        }
    }

    private func blocked(
        _ state: SokobanState,
        at position: GridPosition
    ) -> Transition<SokobanState> {
        Transition(
            state: state,
            events: [.movementBlocked(at: position)],
            outcome: .blocked
        )
    }

    private func pushCrate(
        id: EntityID,
        from: GridPosition,
        cratePosition: GridPosition,
        direction: Direction,
        in state: SokobanState
    ) throws(EngineFault) -> Transition<SokobanState> {
        let destination = cratePosition.neighbor(in: direction)

        guard state.grid.contains(destination) else {
            return blocked(state, at: cratePosition)
        }

        let destinationCell = state.grid[destination]
        guard destinationCell.isWalkable, destinationCell.occupant == nil else {
            return blocked(state, at: cratePosition)
        }

        let crateRef = EntityRef(id: id, kind: .crate)
        let leftGoal = state.grid[cratePosition].isGoal
        let enteredGoal = destinationCell.isGoal
        let completedBefore = state.completedGoalCount
        let totalGoals = state.goalCount

        var next = state
        next.grid[cratePosition].occupant = nil
        next.grid[destination].occupant = .crate(id)

        var completedAfterLeave = completedBefore
        if leftGoal {
            completedAfterLeave -= 1
        }
        var completedAfterEnter = completedAfterLeave
        if enteredGoal {
            completedAfterEnter += 1
        }

        let events: [GameEvent] = [
            .objectPushed(crateRef, from: cratePosition, to: destination),
        ]

        return try movePlayer(
            from: from,
            to: cratePosition,
            in: next,
            didPush: true,
            eventsPrefix: events,
            goalEvents: {
                var goalEvents: [GameEvent] = []
                if leftGoal {
                    goalEvents.append(
                        .crateLeftGoal(
                            crateRef,
                            at: cratePosition,
                            completed: completedAfterLeave,
                            total: totalGoals
                        )
                    )
                }
                if enteredGoal {
                    goalEvents.append(
                        .crateEnteredGoal(
                            crateRef,
                            at: destination,
                            completed: completedAfterEnter,
                            total: totalGoals
                        )
                    )
                }
                return goalEvents
            }()
        )
    }

    private func movePlayer(
        from: GridPosition,
        to: GridPosition,
        in state: SokobanState,
        didPush: Bool,
        eventsPrefix: [GameEvent],
        goalEvents: [GameEvent] = []
    ) throws(EngineFault) -> Transition<SokobanState> {
        var next = state
        guard next.grid.contains(to) else {
            throw .invariantViolated("Player move target outside grid")
        }
        guard next.grid[to].isWalkable, next.grid[to].occupant == nil else {
            throw .invariantViolated("Player move target is not free")
        }

        next.playerPosition = to
        next.moveCount += 1
        if didPush {
            next.pushCount += 1
        }

        var events = eventsPrefix
        events.append(.entityMoved(next.playerRef, from: from, to: to))
        events.append(contentsOf: goalEvents)

        if next.allGoalsCompleted {
            next.status = .completed
            events.append(.levelCompleted)
            return Transition(state: next, events: events, outcome: .terminal(.completed))
        }

        return Transition(state: next, events: events, outcome: .changed)
    }
}
