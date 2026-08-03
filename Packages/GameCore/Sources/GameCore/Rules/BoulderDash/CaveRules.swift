/// Deterministic cave rule engine (Phase 3.7 spike / Phase 4 core).
///
/// Tick semantics follow ADR 0005: player phase, then simultaneous gravity
/// intents from the post-player snapshot, then exit / time / terminal checks.
public struct CaveRules: Sendable {
    public static let ruleVersion: Int = 1
    public static let fixedStepSeconds: Double = 0.10

    public init() {}

    public func start(level: CaveLevel) throws(EngineFault) -> CaveState {
        try validateLevel(level)

        let playerID = EntityID(1)
        var cells: [CaveCell] = []
        cells.reserveCapacity(level.width * level.height)
        var nextEntityID: UInt64 = 2
        var occupantByPosition: [GridPosition: CaveOccupant] = [:]

        for start in level.occupantStarts {
            let id = EntityID(nextEntityID)
            nextEntityID += 1
            let occupant: CaveOccupant
            switch start.kind {
            case .boulder:
                occupant = .boulder(id, motion: .resting)
            case .diamond:
                occupant = .diamond(id, motion: .resting)
            }
            occupantByPosition[start.position] = occupant
        }

        for row in 0..<level.height {
            for column in 0..<level.width {
                let position = GridPosition(column: column, row: row)
                var terrain = level.terrain[position]
                if case .exit = terrain, level.requiredDiamonds == 0 {
                    terrain = .exit(.open)
                }
                cells.append(CaveCell(terrain: terrain, occupant: occupantByPosition[position]))
            }
        }

        let state = CaveState(
            grid: Grid(width: level.width, height: level.height, cells: cells),
            player: .alive(at: level.playerStart),
            playerID: playerID,
            status: .playing,
            tick: 0,
            score: 0,
            collectedDiamonds: 0,
            requiredDiamonds: level.requiredDiamonds,
            diamondValue: level.diamondValue,
            extraDiamondValue: level.extraDiamondValue,
            remainingTicks: level.timeLimitTicks,
            nextEntityID: nextEntityID
        )
        try state.validateEssentials()
        return state
    }

    public func tick(
        input: CaveInput?,
        state: CaveState
    ) throws(EngineFault) -> Transition<CaveState> {
        try state.validateEssentials()

        guard state.status == .playing else {
            return Transition(state: state, events: [], outcome: .blocked)
        }

        var working = state
        var events: [GameEvent] = []

        applyPlayer(input: input ?? .wait, to: &working, events: &events)
        if working.status != .playing {
            working.tick += 1
            try working.validateEssentials()
            return Transition(state: working, events: events, outcome: .terminal(working.status))
        }

        applyGravity(to: &working, events: &events)
        if working.status != .playing {
            working.tick += 1
            try working.validateEssentials()
            return Transition(state: working, events: events, outcome: .terminal(working.status))
        }

        openExitsIfNeeded(in: &working, events: &events)

        if case .alive(let position) = working.player,
           case .exit(.open) = working.grid[position].terrain {
            working.status = .completed
            events.append(.levelCompleted)
            working.tick += 1
            try working.validateEssentials()
            return Transition(state: working, events: events, outcome: .terminal(.completed))
        }

        // Consume one tick of time after physics. Expiry clamps to 0 so
        // `timeLimitTicks == 0` fails cleanly instead of going negative.
        if working.remainingTicks <= 1 {
            working.remainingTicks = 0
            if case .alive(let position) = working.player {
                working.player = .dead(at: position)
            }
            working.status = .failed
            events.append(.timeExpired)
            events.append(.playerDied(at: deathSite(of: working)))
            working.tick += 1
            try working.validateEssentials()
            return Transition(state: working, events: events, outcome: .terminal(.failed))
        }
        working.remainingTicks -= 1

        working.tick += 1
        try working.validateEssentials()
        return Transition(state: working, events: events, outcome: .changed)
    }

    // MARK: - Player

    private func applyPlayer(
        input: CaveInput,
        to state: inout CaveState,
        events: inout [GameEvent]
    ) {
        guard case .alive(let from) = state.player else { return }
        guard case .move(let direction) = input else { return }

        let to = from.neighbor(in: direction)
        guard state.grid.contains(to) else {
            events.append(.movementBlocked(at: from))
            return
        }

        let destination = state.grid[to]
        switch CaveWorldQuery.presence(in: state, at: to) {
        case .blocked:
            switch destination.terrain {
            case .dirt, .exit(.open):
                break
            default:
                events.append(.movementBlocked(at: to))
                return
            }
        case .player:
            return
        case .occupant(let occupant):
            switch occupant {
            case .boulder(_, let motion):
                guard motion == .resting,
                      direction == .left || direction == .right else {
                    if motion == .falling {
                        killPlayer(at: to, causingOccupant: occupant, in: &state, events: &events)
                    } else {
                        events.append(.movementBlocked(at: to))
                    }
                    return
                }
                let beyond = to.neighbor(in: direction)
                guard CaveWorldQuery.presence(in: state, at: beyond) == .empty else {
                    events.append(.movementBlocked(at: to))
                    return
                }
                let ref = EntityRef(id: occupant.id, kind: .boulder)
                state.grid[beyond].occupant = .boulder(occupant.id, motion: .resting)
                state.grid[to].occupant = nil
                events.append(.objectPushed(ref, from: to, to: beyond))
                movePlayer(from: from, to: to, digging: false, in: &state, events: &events)
                return
            case .diamond(let id, let motion):
                guard motion == .resting else {
                    killPlayer(at: to, causingOccupant: occupant, in: &state, events: &events)
                    return
                }
                collectDiamond(id: id, at: to, in: &state, events: &events)
                movePlayer(from: from, to: to, digging: false, in: &state, events: &events)
                return
            }
        case .empty:
            break
        }

        switch destination.terrain {
        case .dirt:
            movePlayer(from: from, to: to, digging: true, in: &state, events: &events)
        case .floor, .exit(.open):
            movePlayer(from: from, to: to, digging: false, in: &state, events: &events)
        case .exit(.closed), .wall, .steelWall, .void:
            events.append(.movementBlocked(at: to))
        }
    }

    private func movePlayer(
        from: GridPosition,
        to: GridPosition,
        digging: Bool,
        in state: inout CaveState,
        events: inout [GameEvent]
    ) {
        if digging {
            state.grid[to] = CaveCell(terrain: .floor, occupant: state.grid[to].occupant)
        }
        state.player = .alive(at: to)
        events.append(.entityMoved(state.playerRef, from: from, to: to))
    }

    private func collectDiamond(
        id: EntityID,
        at position: GridPosition,
        in state: inout CaveState,
        events: inout [GameEvent]
    ) {
        state.grid[position].occupant = nil
        state.collectedDiamonds += 1
        let value = state.collectedDiamonds <= state.requiredDiamonds
            ? state.diamondValue
            : state.extraDiamondValue
        state.score += value
        events.append(
            .diamondCollected(
                EntityRef(id: id, kind: .diamond),
                at: position,
                total: state.collectedDiamonds
            )
        )
    }

    // MARK: - Gravity

    private struct GravityIntent: Equatable {
        enum Kind: Equatable {
            case beginFalling
            case move(to: GridPosition, motion: FallingState)
            case land
        }

        let from: GridPosition
        let occupant: CaveOccupant
        let kind: Kind
    }

    private func applyGravity(to state: inout CaveState, events: inout [GameEvent]) {
        var intents: [GravityIntent] = []
        var claimedDestinations: Set<GridPosition> = []

        for row in 0..<state.grid.height {
            for column in 0..<state.grid.width {
                let from = GridPosition(column: column, row: row)
                guard let occupant = state.grid[from].occupant else { continue }
                guard let intent = gravityIntent(for: occupant, at: from, in: state) else {
                    continue
                }
                if case .move(let to, _) = intent.kind {
                    if claimedDestinations.contains(to) {
                        // Conflict: earlier (top-left) intent wins; this one lands or waits.
                        if occupant.motion == .falling {
                            intents.append(GravityIntent(from: from, occupant: occupant, kind: .land))
                        }
                        continue
                    }
                    claimedDestinations.insert(to)
                }
                intents.append(intent)
            }
        }

        for intent in intents {
            applyGravityIntent(intent, to: &state, events: &events)
            if state.status != .playing { return }
        }
    }

    private func gravityIntent(
        for occupant: CaveOccupant,
        at from: GridPosition,
        in state: CaveState
    ) -> GravityIntent? {
        let below = from.neighbor(in: .down)
        let belowPresence = CaveWorldQuery.presence(in: state, at: below)

        if CaveWorldQuery.canFallInto(in: state, at: below, motion: occupant.motion) {
            switch occupant.motion {
            case .resting:
                return GravityIntent(from: from, occupant: occupant, kind: .beginFalling)
            case .falling:
                return GravityIntent(
                    from: from,
                    occupant: occupant,
                    kind: .move(to: below, motion: .falling)
                )
            }
        }

        // Roll on round support when below is blocked by occupant (not player/empty).
        if CaveWorldQuery.isRoundSupport(belowPresence) {
            let left = from.neighbor(in: .left)
            let leftDown = left.neighbor(in: .down)
            if CaveWorldQuery.presence(in: state, at: left) == .empty,
               CaveWorldQuery.canFallInto(in: state, at: leftDown, motion: .falling) {
                return GravityIntent(
                    from: from,
                    occupant: occupant,
                    kind: .move(to: leftDown, motion: .falling)
                )
            }

            let right = from.neighbor(in: .right)
            let rightDown = right.neighbor(in: .down)
            if CaveWorldQuery.presence(in: state, at: right) == .empty,
               CaveWorldQuery.canFallInto(in: state, at: rightDown, motion: .falling) {
                return GravityIntent(
                    from: from,
                    occupant: occupant,
                    kind: .move(to: rightDown, motion: .falling)
                )
            }
        }

        if occupant.motion == .falling {
            return GravityIntent(from: from, occupant: occupant, kind: .land)
        }
        return nil
    }

    private func applyGravityIntent(
        _ intent: GravityIntent,
        to state: inout CaveState,
        events: inout [GameEvent]
    ) {
        let ref = intent.occupant.entityRef
        switch intent.kind {
        case .beginFalling:
            state.grid[intent.from].occupant = intent.occupant.withMotion(.falling)
            events.append(.objectStartedFalling(ref, at: intent.from))
        case .land:
            state.grid[intent.from].occupant = intent.occupant.withMotion(.resting)
            events.append(.objectLanded(ref, at: intent.from))
            // Landing on player is handled when moving onto the cell, not here.
        case .move(let to, let motion):
            let presence = CaveWorldQuery.presence(in: state, at: to)
            state.grid[intent.from].occupant = nil
            let moved = intent.occupant.withMotion(motion)
            switch presence {
            case .empty:
                state.grid[to].occupant = moved
                events.append(.entityMoved(ref, from: intent.from, to: to))
            case .player:
                state.grid[to].occupant = moved
                events.append(.entityMoved(ref, from: intent.from, to: to))
                killPlayer(at: to, causingOccupant: moved, in: &state, events: &events)
            case .occupant, .blocked:
                // Should not happen after conflict resolution; restore source.
                state.grid[intent.from].occupant = intent.occupant
            }
        }
    }

    // MARK: - Exit / death helpers

    private func openExitsIfNeeded(in state: inout CaveState, events: inout [GameEvent]) {
        guard state.collectedDiamonds >= state.requiredDiamonds else { return }
        for row in 0..<state.grid.height {
            for column in 0..<state.grid.width {
                let position = GridPosition(column: column, row: row)
                if case .exit(.closed) = state.grid[position].terrain {
                    let occupant = state.grid[position].occupant
                    state.grid[position] = CaveCell(terrain: .exit(.open), occupant: occupant)
                    events.append(.exitOpened(at: position))
                }
            }
        }
    }

    private func killPlayer(
        at position: GridPosition,
        causingOccupant: CaveOccupant?,
        in state: inout CaveState,
        events: inout [GameEvent]
    ) {
        _ = causingOccupant
        state.player = .dead(at: position)
        state.status = .failed
        events.append(.playerDied(at: position))
    }

    private func deathSite(of state: CaveState) -> GridPosition {
        switch state.player {
        case .alive(let position), .dead(let position):
            return position
        }
    }

    private func validateLevel(_ level: CaveLevel) throws(EngineFault) {
        guard level.width > 0, level.height > 0 else {
            throw .invariantViolated("Level must be non-empty")
        }
        guard level.terrain.width == level.width, level.terrain.height == level.height else {
            throw .invariantViolated("Terrain grid size mismatch")
        }
        guard level.timeLimitTicks >= 0 else {
            throw .invariantViolated("timeLimitTicks must be non-negative")
        }
        guard level.gridContainsPlayerAndOccupants() else {
            throw .invariantViolated("Start positions out of bounds or overlapping")
        }
    }
}

private extension CaveLevel {
    func gridContainsPlayerAndOccupants() -> Bool {
        guard terrain.contains(playerStart) else { return false }
        var seen = Set<GridPosition>([playerStart])
        for start in occupantStarts {
            guard terrain.contains(start.position) else { return false }
            guard seen.insert(start.position).inserted else { return false }
            guard terrain[start.position] == .floor else { return false }
        }
        return true
    }
}
