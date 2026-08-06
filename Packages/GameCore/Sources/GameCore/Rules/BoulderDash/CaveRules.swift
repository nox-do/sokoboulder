/// Deterministic cave rule engine (Phase 3.7 spike / Phase 4 core / Phase 5.1 enemies).
///
/// Tick semantics follow ADR 0005: player → gravity → enemies → explosion queue →
/// exit / time / terminal checks. Intents are simultaneous from each phase snapshot.
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
            case .firefly:
                occupant = .firefly(id, heading: start.heading)
            case .butterfly:
                occupant = .butterfly(id, heading: start.heading)
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
        var explosions: [PendingExplosion] = []

        applyPlayer(input: input ?? .wait, to: &working, events: &events, explosions: &explosions)
        drainExplosions(&explosions, in: &working, events: &events)
        if working.status != .playing {
            working.tick += 1
            try working.validateEssentials()
            return Transition(state: working, events: events, outcome: .terminal(working.status))
        }

        applyGravity(to: &working, events: &events, explosions: &explosions)
        drainExplosions(&explosions, in: &working, events: &events)
        if working.status != .playing {
            working.tick += 1
            try working.validateEssentials()
            return Transition(state: working, events: events, outcome: .terminal(working.status))
        }

        // Half-rate enemies: act on even ticks (0, 2, 4, …) so classic fly
        // AI stays readable at 10 Hz without changing gravity/player cadence.
        if working.tick % 2 == 0 {
            applyEnemies(to: &working, events: &events, explosions: &explosions)
            drainExplosions(&explosions, in: &working, events: &events)
            if working.status != .playing {
                working.tick += 1
                try working.validateEssentials()
                return Transition(state: working, events: events, outcome: .terminal(working.status))
            }
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
        events: inout [GameEvent],
        explosions: inout [PendingExplosion]
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
            case .firefly, .butterfly:
                triggerEnemyExplosion(occupant, at: to, in: &state, explosions: &explosions)
                killPlayer(at: to, causingOccupant: occupant, in: &state, events: &events)
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

    private func applyGravity(
        to state: inout CaveState,
        events: inout [GameEvent],
        explosions: inout [PendingExplosion]
    ) {
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
            applyGravityIntent(intent, to: &state, events: &events, explosions: &explosions)
            if state.status != .playing { return }
        }
    }

    private func gravityIntent(
        for occupant: CaveOccupant,
        at from: GridPosition,
        in state: CaveState
    ) -> GravityIntent? {
        guard occupant.isGravityAffected, let motion = occupant.motion else { return nil }

        let below = from.neighbor(in: .down)
        let belowPresence = CaveWorldQuery.presence(in: state, at: below)

        if CaveWorldQuery.canFallInto(in: state, at: below, motion: motion) {
            switch motion {
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

        if motion == .falling {
            return GravityIntent(from: from, occupant: occupant, kind: .land)
        }
        return nil
    }

    private func applyGravityIntent(
        _ intent: GravityIntent,
        to state: inout CaveState,
        events: inout [GameEvent],
        explosions: inout [PendingExplosion]
    ) {
        let ref = intent.occupant.entityRef
        switch intent.kind {
        case .beginFalling:
            state.grid[intent.from].occupant = intent.occupant.withMotion(.falling)
            events.append(.objectStartedFalling(ref, at: intent.from))
        case .land:
            state.grid[intent.from].occupant = intent.occupant.withMotion(.resting)
            events.append(.objectLanded(ref, at: intent.from))
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
            case .occupant(let target):
                if target.isEnemy {
                    // Impact: rock/diamond occupies the cell; the queued explosion
                    // then destroys the 3×3 (including this occupant).
                    state.grid[to].occupant = moved
                    events.append(.entityMoved(ref, from: intent.from, to: to))
                    triggerEnemyExplosion(target, at: to, in: &state, explosions: &explosions)
                } else {
                    // Should not happen after conflict resolution; restore source.
                    state.grid[intent.from].occupant = intent.occupant
                }
            case .blocked:
                state.grid[intent.from].occupant = intent.occupant
            }
        }
    }

    // MARK: - Enemies

    private struct EnemyIntent: Equatable {
        let from: GridPosition
        let occupant: CaveOccupant
        let heading: Direction
        let destination: GridPosition?
    }

    private func applyEnemies(
        to state: inout CaveState,
        events: inout [GameEvent],
        explosions: inout [PendingExplosion]
    ) {
        let snapshot = state
        var intents: [EnemyIntent] = []
        var claimedDestinations: Set<GridPosition> = []

        for row in 0..<snapshot.grid.height {
            for column in 0..<snapshot.grid.width {
                let from = GridPosition(column: column, row: row)
                guard let occupant = snapshot.grid[from].occupant, occupant.isEnemy else {
                    continue
                }
                let intent = enemyIntent(for: occupant, at: from, in: snapshot)
                if let destination = intent.destination {
                    if claimedDestinations.contains(destination) {
                        continue
                    }
                    claimedDestinations.insert(destination)
                }
                intents.append(intent)
            }
        }

        for intent in intents {
            applyEnemyIntent(intent, to: &state, events: &events, explosions: &explosions)
            if state.status != .playing { return }
        }
    }

    /// Classic Boulder Dash fly AI (BDCFF / C64): prefer-hand turn+move, else
    /// forward, else turn against preference and stay put for this beat.
    /// Open-space 2×2 orbits are intentional — no wall-seek.
    private func enemyIntent(
        for occupant: CaveOccupant,
        at from: GridPosition,
        in state: CaveState
    ) -> EnemyIntent {
        let heading = occupant.heading ?? .left
        let preferLeft = {
            if case .firefly = occupant { return true }
            return false
        }()
        let preferred = preferLeft ? heading.turnedLeft : heading.turnedRight
        let against = preferLeft ? heading.turnedRight : heading.turnedLeft

        let preferredDestination = from.neighbor(in: preferred)
        if isEnemyEnterable(preferredDestination, in: state) {
            return EnemyIntent(
                from: from,
                occupant: occupant,
                heading: preferred,
                destination: preferredDestination
            )
        }

        let forwardDestination = from.neighbor(in: heading)
        if isEnemyEnterable(forwardDestination, in: state) {
            return EnemyIntent(
                from: from,
                occupant: occupant,
                heading: heading,
                destination: forwardDestination
            )
        }

        // Against-preference turn costs a beat (no move) — classic BD timing.
        return EnemyIntent(
            from: from,
            occupant: occupant,
            heading: against,
            destination: nil
        )
    }

    private func isEnemyEnterable(_ position: GridPosition, in state: CaveState) -> Bool {
        switch CaveWorldQuery.presence(in: state, at: position) {
        case .empty, .player: true
        case .occupant, .blocked: false
        }
    }

    private func applyEnemyIntent(
        _ intent: EnemyIntent,
        to state: inout CaveState,
        events: inout [GameEvent],
        explosions: inout [PendingExplosion]
    ) {
        // Source may already have been cleared by an earlier explosion this tick.
        guard let current = state.grid[intent.from].occupant,
              current.id == intent.occupant.id else {
            return
        }

        let updated = current.withHeading(intent.heading)
        guard let destination = intent.destination else {
            state.grid[intent.from].occupant = updated
            return
        }

        switch CaveWorldQuery.presence(in: state, at: destination) {
        case .empty:
            state.grid[intent.from].occupant = nil
            state.grid[destination].occupant = updated
            events.append(.entityMoved(updated.entityRef, from: intent.from, to: destination))
        case .player:
            state.grid[intent.from].occupant = nil
            state.grid[destination].occupant = updated
            events.append(.entityMoved(updated.entityRef, from: intent.from, to: destination))
            triggerEnemyExplosion(updated, at: destination, in: &state, explosions: &explosions)
            killPlayer(at: destination, causingOccupant: updated, in: &state, events: &events)
        case .occupant, .blocked:
            // Destination filled since intent scan; keep heading update only.
            state.grid[intent.from].occupant = updated
        }
    }

    // MARK: - Explosions

    private struct PendingExplosion: Equatable {
        let center: GridPosition
        let kind: CaveExplosionKind
    }

    private func triggerEnemyExplosion(
        _ enemy: CaveOccupant,
        at position: GridPosition,
        in state: inout CaveState,
        explosions: inout [PendingExplosion]
    ) {
        guard let kind = enemy.explosionKind else { return }
        if let current = state.grid[position].occupant, current.id == enemy.id {
            state.grid[position].occupant = nil
        }
        explosions.append(PendingExplosion(center: position, kind: kind))
    }

    private func drainExplosions(
        _ queue: inout [PendingExplosion],
        in state: inout CaveState,
        events: inout [GameEvent]
    ) {
        var index = 0
        while index < queue.count {
            let pending = queue[index]
            index += 1
            applyExplosion(pending, in: &state, events: &events, queue: &queue)
        }
        queue.removeAll(keepingCapacity: true)
    }

    private func applyExplosion(
        _ explosion: PendingExplosion,
        in state: inout CaveState,
        events: inout [GameEvent],
        queue: inout [PendingExplosion]
    ) {
        var changes: [CellChange] = []

        for rowOffset in -1...1 {
            for columnOffset in -1...1 {
                let position = GridPosition(
                    column: explosion.center.column + columnOffset,
                    row: explosion.center.row + rowOffset
                )
                guard state.grid.contains(position) else { continue }

                if case .alive(let playerPosition) = state.player, playerPosition == position {
                    killPlayer(at: position, causingOccupant: nil, in: &state, events: &events)
                }

                let cell = state.grid[position]
                switch cell.terrain {
                case .steelWall, .void, .exit:
                    continue
                case .wall, .dirt, .floor:
                    break
                }

                var chained = false
                if let occupant = cell.occupant {
                    if let kind = occupant.explosionKind {
                        state.grid[position].occupant = nil
                        queue.append(PendingExplosion(center: position, kind: kind))
                        chained = true
                    } else {
                        state.grid[position].occupant = nil
                    }
                }

                state.grid[position] = CaveCell(terrain: .floor, occupant: nil)

                // Chained enemy cells are filled by their own explosion, not this one.
                if !chained, explosion.kind == .diamondGenerating {
                    let id = EntityID(state.nextEntityID)
                    state.nextEntityID += 1
                    state.grid[position].occupant = .diamond(id, motion: .resting)
                }

                changes.append(CellChange(position: position))
            }
        }

        events.append(.explosion(center: explosion.center, changes: changes))
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
        guard case .alive = state.player else { return }
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
