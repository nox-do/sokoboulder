/// Deterministic Sokoban rule engine.
///
/// Accepts only validated ``SokobanLevel`` values. Crate and player entity IDs
/// are assigned in ``start(level:)`` so two starts of the same level produce
/// identical states. Public transitions check essential invariants in all builds.
public struct SokobanRules: Sendable {
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
