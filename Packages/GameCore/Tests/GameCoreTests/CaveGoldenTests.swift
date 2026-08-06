import Testing
@testable import GameCore

@Suite("Cave golden conflict grids (ADR 0005)")
struct CaveGoldenTests {
    private let rules = CaveRules()

    @Test("boulder falls into empty space with one-tick lag")
    func boulderFallsIntoEmpty() throws {
        var state = try start("""
            ####
            #O #
            #  #
            #  #
            #XX#
            #PE#
            ####
            """)
        let boulderID = EntityID(2)

        let begin = try rules.tick(input: .wait, state: state)
        #expect(begin.outcome == .changed)
        state = begin.state
        #expect(motion(at: GridPosition(column: 1, row: 1), in: state) == .falling)
        #expect(begin.events.contains(.objectStartedFalling(
            EntityRef(id: boulderID, kind: .boulder),
            at: GridPosition(column: 1, row: 1)
        )))

        let fall = try rules.tick(input: .wait, state: state)
        state = fall.state
        #expect(state.grid[GridPosition(column: 1, row: 1)].occupant == nil)
        #expect(motion(at: GridPosition(column: 1, row: 2), in: state) == .falling)

        state = try rules.tick(input: .wait, state: state).state
        let land = try rules.tick(input: .wait, state: state)
        state = land.state
        #expect(motion(at: GridPosition(column: 1, row: 3), in: state) == .resting)
        #expect(land.events.contains(.objectLanded(
            EntityRef(id: boulderID, kind: .boulder),
            at: GridPosition(column: 1, row: 3)
        )))
    }

    @Test("resting boulder on player does not kill")
    func restingBoulderDoesNotKillPlayer() throws {
        var state = try start("""
            ###
            #O#
            #P#
            #E#
            ###
            """)
        let idle = try rules.tick(input: .wait, state: state)
        state = idle.state
        #expect(state.status == .playing)
        #expect(state.player == .alive(at: GridPosition(column: 1, row: 2)))
        #expect(motion(at: GridPosition(column: 1, row: 1), in: state) == .resting)
    }

    @Test("falling boulder kills player")
    func fallingBoulderKillsPlayer() throws {
        var state = try start("""
            ###
            #O#
            # #
            #P#
            #E#
            ###
            """)
        state = try rules.tick(input: .wait, state: state).state // begin falling
        state = try rules.tick(input: .wait, state: state).state // move onto empty
        let kill = try rules.tick(input: .wait, state: state)
        #expect(kill.outcome == .terminal(.failed))
        #expect(kill.state.status == .failed)
        #expect(kill.state.player == .dead(at: GridPosition(column: 1, row: 3)))
        #expect(kill.events.contains(.playerDied(at: GridPosition(column: 1, row: 3))))
        #expect(kill.state.grid[GridPosition(column: 1, row: 3)].occupant != nil)
    }

    @Test("player steps aside then boulder falls")
    func playerStepsAsideThenFall() throws {
        var state = try start("""
            ####
            #O #
            #P #
            #E #
            ####
            """)
        state = try rules.tick(input: .move(.right), state: state).state
        #expect(state.player == .alive(at: GridPosition(column: 2, row: 2)))
        #expect(motion(at: GridPosition(column: 1, row: 1), in: state) == .falling)

        state = try rules.tick(input: .wait, state: state).state
        #expect(state.grid[GridPosition(column: 1, row: 1)].occupant == nil)
        #expect(motion(at: GridPosition(column: 1, row: 2), in: state) == .falling)
        #expect(state.status == .playing)
    }

    @Test("boulder can be pushed horizontally")
    func boulderPushHorizontal() throws {
        var state = try start("""
            #######
            #  PO #
            #    E#
            #######
            """)
        let push = try rules.tick(input: .move(.right), state: state)
        state = push.state
        #expect(state.player == .alive(at: GridPosition(column: 4, row: 1)))
        #expect(state.grid[GridPosition(column: 5, row: 1)].occupant != nil)
        #expect(push.events.contains {
            if case .objectPushed(_, let from, let to) = $0 {
                return from == GridPosition(column: 4, row: 1) && to == GridPosition(column: 5, row: 1)
            }
            return false
        })
    }

    @Test("boulder cannot be pushed vertically")
    func boulderNoVerticalPush() throws {
        let state = try start("""
            ###
            #P#
            #O#
            # #
            #E#
            ###
            """)
        let blocked = try rules.tick(input: .move(.down), state: state)
        #expect(blocked.state.player == .alive(at: GridPosition(column: 1, row: 1)))
        #expect(blocked.state.grid[GridPosition(column: 1, row: 2)].occupant != nil)
        #expect(blocked.events.contains(.movementBlocked(at: GridPosition(column: 1, row: 2))))
    }

    @Test("boulder rolls left when left path is open")
    func boulderRollsLeftPreferred() throws {
        var state = try start("""
            #####
            # O #
            # O #
            #   #
            #P E#
            #####
            """)
        let roll = try rules.tick(input: .wait, state: state)
        state = roll.state
        #expect(state.grid[GridPosition(column: 2, row: 1)].occupant == nil)
        #expect(motion(at: GridPosition(column: 1, row: 2), in: state) == .falling)
    }

    @Test("boulder rolls right when left is blocked")
    func boulderRollsRightWhenLeftBlocked() throws {
        var state = try start("""
            #####
            ##O #
            ##O #
            #   #
            #P E#
            #####
            """)
        let roll = try rules.tick(input: .wait, state: state)
        state = roll.state
        #expect(state.grid[GridPosition(column: 2, row: 1)].occupant == nil)
        #expect(motion(at: GridPosition(column: 3, row: 2), in: state) == .falling)
    }

    @Test("object updates at most once per tick while falling")
    func updateOnceSameTick() throws {
        var state = try start("""
            ####
            #O #
            #  #
            #  #
            #  #
            #PE#
            ####
            """)
        state = try rules.tick(input: .wait, state: state).state // falling
        let moved = try rules.tick(input: .wait, state: state)
        state = moved.state
        #expect(state.grid[GridPosition(column: 1, row: 1)].occupant == nil)
        #expect(motion(at: GridPosition(column: 1, row: 2), in: state) == .falling)
        #expect(state.grid[GridPosition(column: 1, row: 3)].occupant == nil)
    }

    @Test("roll conflict: earlier scan wins shared destination")
    func twoIntentsSameCell() throws {
        var state = try start("""
            #########
            ###O O###
            ###* *###
            ##     ##
            ## P E ##
            #########
            """, requiredDiamonds: 0)
        let tick = try rules.tick(input: .wait, state: state)
        state = tick.state
        let destination = GridPosition(column: 4, row: 2)
        #expect(state.grid[destination].occupant != nil)
        #expect(state.grid[GridPosition(column: 3, row: 1)].occupant == nil)
        #expect(state.grid[GridPosition(column: 5, row: 1)].occupant != nil)
    }

    @Test("player digs dirt")
    func playerDigsDirt() throws {
        var state = try start("""
            ####
            #P.#
            #E #
            ####
            """)
        let dig = try rules.tick(input: .move(.right), state: state)
        state = dig.state
        #expect(state.player == .alive(at: GridPosition(column: 2, row: 1)))
        #expect(state.grid[GridPosition(column: 2, row: 1)].terrain == .floor)
    }

    @Test("exit opens at required diamond count; enter to complete")
    func exitOpensAtRequired() throws {
        var state = try start("""
            #####
            #P*E#
            #####
            """, requiredDiamonds: 1)
        #expect(state.grid[GridPosition(column: 3, row: 1)].terrain == .exit(.closed))
        let collect = try rules.tick(input: .move(.right), state: state)
        state = collect.state
        #expect(state.collectedDiamonds == 1)
        #expect(state.grid[GridPosition(column: 3, row: 1)].terrain == .exit(.open))
        #expect(collect.events.contains(.exitOpened(at: GridPosition(column: 3, row: 1))))
        #expect(state.status == .playing)

        let finish = try rules.tick(input: .move(.right), state: state)
        #expect(finish.outcome == .terminal(.completed))
        #expect(finish.events.contains(.levelCompleted))
    }

    @Test("time expiry kills the player")
    func timeExpiresKills() throws {
        let state = try start("""
            ###
            #P#
            #E#
            ###
            """, requiredDiamonds: 0, timeLimitTicks: 1)
        let expired = try rules.tick(input: .wait, state: state)
        #expect(expired.outcome == .terminal(.failed))
        #expect(expired.events.contains(.timeExpired))
        #expect(expired.events.contains(.playerDied(at: GridPosition(column: 1, row: 1))))
    }

    @Test("zero time limit fails on first tick without EngineFault")
    func zeroTimeLimitFailsCleanly() throws {
        let state = try start("""
            ###
            #P#
            #E#
            ###
            """, requiredDiamonds: 0, timeLimitTicks: 0)
        let expired = try rules.tick(input: .wait, state: state)
        #expect(expired.outcome == .terminal(.failed))
        #expect(expired.state.remainingTicks == 0)
        #expect(expired.events.contains(.timeExpired))
    }

    @Test("moving into a falling boulder kills the player")
    func moveIntoFallingBoulderKills() throws {
        var state = try start("""
            ####
            #PO#
            #  #
            #E #
            ####
            """)
        state = try rules.tick(input: .wait, state: state).state
        #expect(motion(at: GridPosition(column: 2, row: 1), in: state) == .falling)
        let kill = try rules.tick(input: .move(.right), state: state)
        #expect(kill.outcome == .terminal(.failed))
        #expect(kill.events.contains(.playerDied(at: GridPosition(column: 2, row: 1))))
    }

    @Test("identical wait sequence yields stable digest")
    func replayDigestStable() throws {
        let level = try CaveLevelBuilder.level(fromASCII: """
            ###
            #O#
            # #
            #P#
            #E#
            ###
            """, timeLimitTicks: 50)
        var stateA = try rules.start(level: level)
        var stateB = try rules.start(level: level)
        for _ in 0..<5 {
            stateA = try rules.tick(input: .wait, state: stateA).state
            stateB = try rules.tick(input: .wait, state: stateB).state
        }
        #expect(CaveStateDigest.sha256Hex(stateA) == CaveStateDigest.sha256Hex(stateB))
        #expect(CaveStateDigest.canonicalString(stateA) == CaveStateDigest.canonicalString(stateB))
    }

    // MARK: - Phase 5.1 enemies + explosions

    @Test("firefly turns left and moves when prefer side is open")
    func fireflyPrefersLeftTurn() throws {
        var state = try start("""
            #####
            #   #
            # F #
            #  P#
            #E  #
            #####
            """)
        // Default heading left → prefer left is down.
        state = try rules.tick(input: .wait, state: state).state
        #expect(state.grid[GridPosition(column: 2, row: 2)].occupant == nil)
        guard case .firefly(_, let heading) = state.grid[GridPosition(column: 2, row: 3)].occupant else {
            Issue.record("expected firefly to turn left (down)")
            return
        }
        #expect(heading == .down)
    }

    @Test("firefly orbits 2x2 in open space (classic BD)")
    func fireflyOrbitsOpenSpace() throws {
        var state = try start("""
            ######
            #    #
            #  F #
            #    #
            #P  E#
            ######
            """)
        // F at (3,2) heading left → (3,3)↓ → (4,3)→ → (4,2)↑ → (3,2)← …
        var seen: [GridPosition] = []
        for _ in 0..<8 {
            state = try rules.tick(input: .wait, state: state).state
            for row in 0..<state.grid.height {
                for column in 0..<state.grid.width {
                    let p = GridPosition(column: column, row: row)
                    if case .firefly = state.grid[p].occupant {
                        if seen.last != p { seen.append(p) }
                    }
                }
            }
        }
        let orbit: Set<GridPosition> = [
            GridPosition(column: 3, row: 2),
            GridPosition(column: 3, row: 3),
            GridPosition(column: 4, row: 3),
            GridPosition(column: 4, row: 2),
        ]
        #expect(Set(seen).isSubset(of: orbit))
        #expect(orbit.isSubset(of: Set(seen)))
    }

    @Test("firefly turns against preference then advances along corridor")
    func fireflyTurnsThenAdvancesAlongCorridor() throws {
        var state = try start("""
            #####
            #F  #
            #. P#
            #E  #
            #####
            """)
        // Prefer left (down) = dirt; forward (left) = wall → turn right (up), stay.
        state = try rules.tick(input: .wait, state: state).state
        guard case .firefly(_, let heading1) = state.grid[GridPosition(column: 1, row: 1)].occupant else {
            Issue.record("expected firefly still at start after against-prefer turn")
            return
        }
        #expect(heading1 == .up)
        state = try rules.tick(input: .wait, state: state).state // odd idle
        // Heading up; prefer left + forward blocked → turn right, stay.
        state = try rules.tick(input: .wait, state: state).state
        guard case .firefly(_, let heading2) = state.grid[GridPosition(column: 1, row: 1)].occupant else {
            Issue.record("expected second against-prefer turn")
            return
        }
        #expect(heading2 == .right)
        state = try rules.tick(input: .wait, state: state).state // odd idle
        // Heading right; prefer up blocked; forward open → move.
        state = try rules.tick(input: .wait, state: state).state
        guard case .firefly(_, let heading3) = state.grid[GridPosition(column: 2, row: 1)].occupant else {
            Issue.record("expected firefly to advance along corridor")
            return
        }
        #expect(heading3 == .right)
    }

    @Test("butterfly prefers right turn and moves when open")
    func butterflyPrefersRightTurn() throws {
        var state = try start("""
            #####
            #   #
            # B #
            #  P#
            #E  #
            #####
            """)
        // Heading left → prefer right is up.
        state = try rules.tick(input: .wait, state: state).state
        #expect(state.grid[GridPosition(column: 2, row: 2)].occupant == nil)
        guard case .butterfly(_, let heading) = state.grid[GridPosition(column: 2, row: 1)].occupant else {
            Issue.record("expected butterfly to turn right (up)")
            return
        }
        #expect(heading == .up)
    }

    @Test("butterfly turns against preference without moving")
    func butterflyTurnsAgainstPreferenceInPlace() throws {
        var state = try start("""
            #####
            ##  #
            #B  #
            #  P#
            #E  #
            #####
            """)
        // Heading left; prefer right (up) = wall; forward (left) = wall → turn left (down), stay.
        state = try rules.tick(input: .wait, state: state).state
        guard case .butterfly(_, let heading) = state.grid[GridPosition(column: 1, row: 2)].occupant else {
            Issue.record("expected butterfly to stay and face down")
            return
        }
        #expect(heading == .down)
        #expect(state.grid[GridPosition(column: 1, row: 3)].occupant == nil)
    }

    @Test("firefly turns into a side tunnel while wall-following")
    func fireflyEntersSideTunnel() throws {
        var state = try start("""
            ########
            #     F#
            ##### ##
            #P   #E#
            ########
            """)
        // Corridor westbound: at the shaft under col 5, prefer-left turns south.
        var enteredShaft = false
        for _ in 0..<48 {
            state = try rules.tick(input: .wait, state: state).state
            if case .firefly = state.grid[GridPosition(column: 5, row: 2)].occupant {
                enteredShaft = true
                break
            }
            if case .firefly = state.grid[GridPosition(column: 5, row: 3)].occupant {
                enteredShaft = true
                break
            }
        }
        #expect(enteredShaft)
    }

    @Test("firefly follows one-tile corridor after prefer turns")
    func fireflyFollowsCorridor() throws {
        var state = try start("""
            ########
            #F     #
            ########
            #P    E#
            ########
            """)
        // Two against-prefer turns (left+forward blocked), then march right.
        for _ in 0..<5 {
            state = try rules.tick(input: .wait, state: state).state
        }
        guard case .firefly(_, let heading) = state.grid[GridPosition(column: 2, row: 1)].occupant else {
            Issue.record("expected firefly one step along corridor")
            return
        }
        #expect(heading == .right)
        state = try rules.tick(input: .wait, state: state).state // odd idle
        state = try rules.tick(input: .wait, state: state).state // even: next step
        guard case .firefly = state.grid[GridPosition(column: 3, row: 1)].occupant else {
            Issue.record("expected firefly second step along corridor")
            return
        }
    }

    @Test("firefly does not oscillate at convex doorway")
    func fireflyLeavesDoorwayWithoutOscillation() throws {
        var state = try start("""
            ########
            #      #
            #    F##
            #      #
            #P    E#
            ########
            """)
        // F at (5,2) under ceiling, beside right wall — prefer left (down) into
        // doorway row, then prefer left (right) out; must not hop forever.
        var positions: [GridPosition] = []
        for _ in 0..<16 {
            state = try rules.tick(input: .wait, state: state).state
            for row in 0..<state.grid.height {
                for column in 0..<state.grid.width {
                    let p = GridPosition(column: column, row: row)
                    if case .firefly = state.grid[p].occupant {
                        positions.append(p)
                    }
                }
            }
        }
        let unique = Set(positions)
        #expect(unique.count >= 3)
        #expect(!unique.isSubset(of: [
            GridPosition(column: 5, row: 2),
            GridPosition(column: 5, row: 3),
        ]))
    }

    @Test("player walking into firefly explodes and dies")
    func playerWalksIntoFirefly() throws {
        let state = try start("""
            ####
            #PF#
            #E #
            ####
            """)
        let kill = try rules.tick(input: .move(.right), state: state)
        #expect(kill.outcome == .terminal(.failed))
        #expect(kill.state.player == .dead(at: GridPosition(column: 2, row: 1)))
        #expect(kill.events.contains(where: {
            if case .explosion(let center, _) = $0 {
                return center == GridPosition(column: 2, row: 1)
            }
            return false
        }))
        #expect(kill.state.grid[GridPosition(column: 2, row: 1)].occupant == nil)
    }

    @Test("falling boulder triggers firefly explosion; steel survives")
    func boulderExplodesFireflySteelSurvives() throws {
        var state = try start("""
            #####
            #XOX#
            #XFX#
            #XXX#
            #P E#
            #####
            """)
        state = try rules.tick(input: .wait, state: state).state // begin falling
        let boom = try rules.tick(input: .wait, state: state)
        state = boom.state
        #expect(boom.events.contains(where: {
            if case .explosion = $0 { return true }
            return false
        }))
        #expect(boom.events.contains(where: {
            if case .entityMoved(let ref, _, let to) = $0 {
                return ref.kind == .boulder && to == GridPosition(column: 2, row: 2)
            }
            return false
        }))
        #expect(state.grid[GridPosition(column: 1, row: 1)].terrain == .steelWall)
        #expect(state.grid[GridPosition(column: 3, row: 1)].terrain == .steelWall)
        #expect(state.grid[GridPosition(column: 2, row: 2)].occupant == nil)
        #expect(state.grid[GridPosition(column: 2, row: 1)].occupant == nil)
        #expect(state.status == .playing)
    }

    @Test("butterfly explosion spawns diamonds")
    func butterflyExplosionSpawnsDiamonds() throws {
        let state = try start("""
            ####
            #PB#
            #E #
            ####
            """, requiredDiamonds: 0)
        let boom = try rules.tick(input: .move(.right), state: state)
        #expect(boom.outcome == .terminal(.failed))
        var diamondCount = 0
        for row in 0..<boom.state.grid.height {
            for column in 0..<boom.state.grid.width {
                if case .diamond = boom.state.grid[GridPosition(column: column, row: row)].occupant {
                    diamondCount += 1
                }
            }
        }
        #expect(diamondCount >= 1)
    }

    @Test("adjacent fireflies chain-explode")
    func fireflyChainExplosion() throws {
        let state = try start("""
            #####
            #PFF#
            #E  #
            #####
            """)
        let boom = try rules.tick(input: .move(.right), state: state)
        #expect(boom.outcome == .terminal(.failed))
        let explosionCount = boom.events.filter {
            if case .explosion = $0 { return true }
            return false
        }.count
        #expect(explosionCount >= 2)
        #expect(boom.state.grid[GridPosition(column: 2, row: 1)].occupant == nil)
        #expect(boom.state.grid[GridPosition(column: 3, row: 1)].occupant == nil)
    }

    // MARK: - Helpers

    private func start(
        _ ascii: String,
        requiredDiamonds: Int? = nil,
        timeLimitTicks: Int = 1_000
    ) throws -> CaveState {
        let level = try CaveLevelBuilder.level(
            fromASCII: ascii,
            requiredDiamonds: requiredDiamonds,
            timeLimitTicks: timeLimitTicks
        )
        return try rules.start(level: level)
    }

    private func motion(at position: GridPosition, in state: CaveState) -> FallingState? {
        state.grid[position].occupant?.motion
    }
}
