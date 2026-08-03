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
