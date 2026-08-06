/// Deterministic cave rule engine (Phase 3.7–5.2b: core, enemies, magic wall, amoeba).
///
/// Tick semantics follow ADR 0005: player → gravity → enemies → amoeba →
/// explosion drains after each phase → exit / time / terminal checks.
/// Intents are simultaneous from each phase snapshot.
public struct CaveRules: Sendable {
    public static let ruleVersion: Int = 1
    public static let fixedStepSeconds: Double = 0.10

    /// BDCFF slow / fast amoeba random factors (`GetRandomNumber(0, factor) < 4`).
    private static let amoebaSlowRandomFactor: UInt32 = 127
    private static let amoebaFastRandomFactor: UInt32 = 15

    public init() {}

    public func start(level: CaveLevel) throws(EngineFault) -> CaveState {
        try validateLevel(level)

        let playerID = EntityID(1)
        var cells: [CaveCell] = []
        cells.reserveCapacity(level.width * level.height)
        var nextEntityID: UInt64 = 2
        var occupantByPosition: [GridPosition: CaveOccupant] = [:]
        var amoebaCount = 0

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
            case .amoeba:
                occupant = .amoeba(id)
                amoebaCount += 1
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
            nextEntityID: nextEntityID,
            magicWallMillingTicks: level.magicWallMillingTicks,
            magicWallStatus: .dormant,
            rng: DeterministicRNG(seed: level.rngSeed),
            amoebaMaxCells: level.amoebaMaxCells,
            amoebaSlowTicksRemaining: level.amoebaSlowGrowthTicks,
            amoebaSlowGrowthStarted: false,
            amoebaCellCountLastTick: amoebaCount,
            amoebaSuffocatedLastTick: false
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

        applyAmoeba(to: &working, events: &events, explosions: &explosions)
        drainExplosions(&explosions, in: &working, events: &events)
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
        tickMagicWallTimer(in: &working)

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
            case .amoeba:
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
        case .exit(.closed), .wall, .steelWall, .magicWall, .void:
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
            /// Hit magic wall: clear source; optionally emerge morphed below.
            case magicWallHit(exit: GridPosition?)
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
                let claim: GridPosition?
                switch intent.kind {
                case .move(let to, _):
                    claim = to
                case .magicWallHit(let exit):
                    claim = exit
                case .beginFalling, .land:
                    claim = nil
                }
                if let destination = claim {
                    if claimedDestinations.contains(destination) {
                        if case .magicWallHit = intent.kind {
                            intents.append(
                                GravityIntent(
                                    from: from,
                                    occupant: occupant,
                                    kind: .magicWallHit(exit: nil)
                                )
                            )
                        } else if occupant.motion == .falling {
                            intents.append(GravityIntent(from: from, occupant: occupant, kind: .land))
                        }
                        continue
                    }
                    claimedDestinations.insert(destination)
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
        if state.grid.contains(below), case .magicWall = state.grid[below].terrain {
            guard motion == .falling else { return nil }
            let exit = below.neighbor(in: .down)
            let canExit: Bool = {
                guard state.grid.contains(exit) else { return false }
                if case .alive(let playerPosition) = state.player, playerPosition == exit {
                    return false
                }
                return CaveWorldQuery.presence(in: state, at: exit) == .empty
            }()
            let willMorph: Bool = {
                switch state.magicWallStatus {
                case .dormant, .active: return canExit
                case .expired: return false
                }
            }()
            return GravityIntent(
                from: from,
                occupant: occupant,
                kind: .magicWallHit(exit: willMorph ? exit : nil)
            )
        }

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

        // Magic wall is not rounded — no roll-off from it.
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
        case .magicWallHit(let exit):
            if case .dormant = state.magicWallStatus {
                state.magicWallStatus = .active(remainingTicks: state.magicWallMillingTicks)
            }
            state.grid[intent.from].occupant = nil
            guard let exit,
                  case .active = state.magicWallStatus,
                  CaveWorldQuery.presence(in: state, at: exit) == .empty
            else {
                return
            }
            let id = EntityID(state.nextEntityID)
            state.nextEntityID += 1
            let morphed = intent.occupant.morphedThroughMagicWall(id: id)
            state.grid[exit].occupant = morphed
            events.append(.entityMoved(morphed.entityRef, from: intent.from, to: exit))
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
                    state.grid[to].occupant = moved
                    events.append(.entityMoved(ref, from: intent.from, to: to))
                    triggerEnemyExplosion(target, at: to, in: &state, explosions: &explosions)
                } else {
                    state.grid[intent.from].occupant = intent.occupant
                }
            case .blocked:
                state.grid[intent.from].occupant = intent.occupant
            }
        }
    }

    private func tickMagicWallTimer(in state: inout CaveState) {
        guard case .active(let remaining) = state.magicWallStatus else { return }
        if remaining <= 1 {
            state.magicWallStatus = .expired
        } else {
            state.magicWallStatus = .active(remainingTicks: remaining - 1)
        }
    }

    // MARK: - Enemies

    private struct EnemyIntent: Equatable {
        let from: GridPosition
        let occupant: CaveOccupant
        let heading: Direction
        let destination: GridPosition?
        let explodeInPlace: Bool
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
    /// Adjacent amoeba → explode in place (contact).
    private func enemyIntent(
        for occupant: CaveOccupant,
        at from: GridPosition,
        in state: CaveState
    ) -> EnemyIntent {
        if isOrthogonallyAdjacentToAmoeba(from, in: state) {
            return EnemyIntent(
                from: from,
                occupant: occupant,
                heading: occupant.heading ?? .left,
                destination: nil,
                explodeInPlace: true
            )
        }

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
                destination: preferredDestination,
                explodeInPlace: false
            )
        }

        let forwardDestination = from.neighbor(in: heading)
        if isEnemyEnterable(forwardDestination, in: state) {
            return EnemyIntent(
                from: from,
                occupant: occupant,
                heading: heading,
                destination: forwardDestination,
                explodeInPlace: false
            )
        }

        // Against-preference turn costs a beat (no move) — classic BD timing.
        return EnemyIntent(
            from: from,
            occupant: occupant,
            heading: against,
            destination: nil,
            explodeInPlace: false
        )
    }

    private func isOrthogonallyAdjacentToAmoeba(_ position: GridPosition, in state: CaveState) -> Bool {
        for direction in Direction.allCases {
            let neighbor = position.neighbor(in: direction)
            guard state.grid.contains(neighbor) else { continue }
            if state.grid[neighbor].occupant?.isAmoeba == true {
                return true
            }
        }
        return false
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

        if intent.explodeInPlace {
            triggerEnemyExplosion(current, at: intent.from, in: &state, explosions: &explosions)
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

    // MARK: - Amoeba

    private enum AmoebaIntent: Equatable {
        case convertToBoulder(at: GridPosition, id: EntityID)
        case convertToDiamond(at: GridPosition, id: EntityID)
        case grow(from: GridPosition, to: GridPosition)
    }

    private func applyAmoeba(
        to state: inout CaveState,
        events: inout [GameEvent],
        explosions: inout [PendingExplosion]
    ) {
        _ = explosions
        let snapshot = state
        var positions: [GridPosition] = []
        var canGrowAny = false

        for row in 0..<snapshot.grid.height {
            for column in 0..<snapshot.grid.width {
                let position = GridPosition(column: column, row: row)
                guard snapshot.grid[position].occupant?.isAmoeba == true else { continue }
                positions.append(position)
                if amoebaCanGrow(from: position, in: snapshot) {
                    canGrowAny = true
                }
            }
        }

        let count = positions.count
        var intents: [AmoebaIntent] = []
        var claimedDestinations: Set<GridPosition> = []

        if count > 0 {
            if snapshot.amoebaCellCountLastTick >= snapshot.amoebaMaxCells {
                for position in positions {
                    guard let id = snapshot.grid[position].occupant?.id else { continue }
                    intents.append(.convertToBoulder(at: position, id: id))
                }
            } else if snapshot.amoebaSuffocatedLastTick {
                for position in positions {
                    guard let id = snapshot.grid[position].occupant?.id else { continue }
                    intents.append(.convertToDiamond(at: position, id: id))
                }
            } else {
                let factor = snapshot.amoebaSlowTicksRemaining > 0
                    ? Self.amoebaSlowRandomFactor
                    : Self.amoebaFastRandomFactor
                for position in positions {
                    guard amoebaRandomlyDecidesToGrow(factor: factor, rng: &state.rng) else {
                        continue
                    }
                    let direction = randomGrowthDirection(rng: &state.rng)
                    let destination = position.neighbor(in: direction)
                    guard isAmoebaGrowthTarget(destination, in: snapshot) else { continue }
                    guard !claimedDestinations.contains(destination) else { continue }
                    claimedDestinations.insert(destination)
                    intents.append(.grow(from: position, to: destination))
                }
            }
        }

        for intent in intents {
            applyAmoebaIntent(intent, to: &state, events: &events)
        }

        // Lag-1 flags for the next tick (BDCFF).
        var nextCount = 0
        for row in 0..<state.grid.height {
            for column in 0..<state.grid.width {
                if state.grid[GridPosition(column: column, row: row)].occupant?.isAmoeba == true {
                    nextCount += 1
                }
            }
        }
        state.amoebaCellCountLastTick = nextCount
        // Suffocation uses this frame's growth *opportunity*, not whether growth succeeded.
        state.amoebaSuffocatedLastTick = count > 0 && !canGrowAny

        // BDCFF BD2: arm slow-growth clock on first growth opportunity; then tick down.
        if canGrowAny {
            state.amoebaSlowGrowthStarted = true
        }
        if state.amoebaSlowGrowthStarted, state.amoebaSlowTicksRemaining > 0 {
            state.amoebaSlowTicksRemaining -= 1
        }
    }

    private func amoebaCanGrow(from position: GridPosition, in state: CaveState) -> Bool {
        for direction in Direction.allCases {
            if isAmoebaGrowthTarget(position.neighbor(in: direction), in: state) {
                return true
            }
        }
        return false
    }

    private func isAmoebaGrowthTarget(_ position: GridPosition, in state: CaveState) -> Bool {
        guard state.grid.contains(position) else { return false }
        if case .alive(let playerPosition) = state.player, playerPosition == position {
            return false
        }
        let cell = state.grid[position]
        guard cell.occupant == nil else { return false }
        switch cell.terrain {
        case .floor, .dirt: return true
        case .void, .wall, .steelWall, .magicWall, .exit: return false
        }
    }

    private func amoebaRandomlyDecidesToGrow(factor: UInt32, rng: inout DeterministicRNG) -> Bool {
        rng.nextInt(upperBound: factor) < 4
    }

    private func randomGrowthDirection(rng: inout DeterministicRNG) -> Direction {
        let directions = Direction.allCases
        let index = Int(rng.nextInt(upperBound: UInt32(directions.count - 1)))
        return directions[index]
    }

    private func applyAmoebaIntent(
        _ intent: AmoebaIntent,
        to state: inout CaveState,
        events: inout [GameEvent]
    ) {
        switch intent {
        case .convertToBoulder(at: let position, id: let id):
            guard state.grid[position].occupant?.id == id else { return }
            let newID = EntityID(state.nextEntityID)
            state.nextEntityID += 1
            state.grid[position].occupant = .boulder(newID, motion: .resting)
        case .convertToDiamond(at: let position, id: let id):
            guard state.grid[position].occupant?.id == id else { return }
            let newID = EntityID(state.nextEntityID)
            state.nextEntityID += 1
            state.grid[position].occupant = .diamond(newID, motion: .resting)
        case .grow(from: let from, to: let to):
            guard state.grid[from].occupant?.isAmoeba == true else { return }
            guard isAmoebaGrowthTarget(to, in: state) else { return }
            if case .dirt = state.grid[to].terrain {
                state.grid[to] = CaveCell(terrain: .floor, occupant: nil)
            }
            let id = EntityID(state.nextEntityID)
            state.nextEntityID += 1
            state.grid[to].occupant = .amoeba(id)
            events.append(.entityMoved(EntityRef(id: id, kind: .amoeba), from: from, to: to))
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
                case .steelWall, .void, .exit, .magicWall:
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
