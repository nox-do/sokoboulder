import Testing
@testable import GameCore

@Suite("SokobanRules")
struct SokobanRulesTests {
    private let rules = SokobanRules()

    private func start(_ ascii: String) throws -> SokobanState {
        let level = try SokobanLevelValidator.level(fromASCII: ascii)
        return try rules.start(level: level)
    }

    @Test("start assigns deterministic player and crate IDs")
    func deterministicStart() throws {
        let ascii = """
            ####
            #@$#
            # .#
            ####
            """
        let a = try start(ascii)
        let b = try start(ascii)
        #expect(a == b)
        #expect(a.playerID == EntityID(1))
        #expect(a.grid[GridPosition(column: 2, row: 1)].occupant == .crate(EntityID(2)))
    }

    @Test("free movement updates position and move count")
    func freeMovement() throws {
        let state = try start("""
            #####
            # @ #
            # .$#
            #####
            """)
        let before = state
        let transition = try rules.move(.left, in: state)
        #expect(transition.outcome == .changed)
        #expect(transition.state.playerPosition == GridPosition(column: 1, row: 1))
        #expect(transition.state.moveCount == 1)
        #expect(transition.state.pushCount == 0)
        #expect(transition.events == [
            .entityMoved(
                state.playerRef,
                from: GridPosition(column: 2, row: 1),
                to: GridPosition(column: 1, row: 1)
            ),
        ])
        // Input state must not be mutated.
        #expect(before == state)
    }

    @Test("wall and void leave state unchanged")
    func blockedByWallAndVoid() throws {
        let state = try start("""
            ###
            #@.
            #$#
            ###
            """)
        let wall = try rules.move(.up, in: state)
        #expect(wall.outcome == .blocked)
        #expect(wall.state == state)
        #expect(wall.events == [.movementBlocked(at: GridPosition(column: 1, row: 0))])

        let open = try start("""
            ----
            -@.-
            -$--
            ----
            """)
        let intoVoid = try rules.move(.left, in: open)
        #expect(intoVoid.outcome == .blocked)
        #expect(intoVoid.state == open)
        #expect(intoVoid.events == [.movementBlocked(at: GridPosition(column: 0, row: 1))])
    }

    @Test("simple crate push increments move and push counts")
    func simplePush() throws {
        let state = try start("""
            ######
            # @$ #
            #  . #
            ######
            """)
        let transition = try rules.move(.right, in: state)
        #expect(transition.outcome == .changed)
        #expect(transition.state.playerPosition == GridPosition(column: 3, row: 1))
        #expect(transition.state.moveCount == 1)
        #expect(transition.state.pushCount == 1)
        #expect(transition.state.grid[GridPosition(column: 4, row: 1)].occupant == .crate(EntityID(2)))
        #expect(transition.state.grid[GridPosition(column: 3, row: 1)].occupant == nil)

        let crate = EntityRef(id: EntityID(2), kind: .crate)
        #expect(transition.events == [
            .objectPushed(
                crate,
                from: GridPosition(column: 3, row: 1),
                to: GridPosition(column: 4, row: 1)
            ),
            .entityMoved(
                state.playerRef,
                from: GridPosition(column: 2, row: 1),
                to: GridPosition(column: 3, row: 1)
            ),
        ])
    }

    @Test("second crate or wall behind crate blocks without changing counters")
    func pushBlocked() throws {
        let againstWall = try start("""
            ####
            #@$#
            # .#
            ####
            """)
        let blockedWall = try rules.move(.right, in: againstWall)
        #expect(blockedWall.outcome == .blocked)
        #expect(blockedWall.state == againstWall)
        #expect(blockedWall.state.moveCount == 0)

        let againstCrate = try start("""
            ######
            # @$$#
            #  ..#
            ######
            """)
        let blockedCrate = try rules.move(.right, in: againstCrate)
        #expect(blockedCrate.outcome == .blocked)
        #expect(blockedCrate.state == againstCrate)
    }

    @Test("crate entering a goal emits ordered events and can complete")
    func enterGoalAndComplete() throws {
        let state = try start("""
            ######
            # @$.#
            ######
            """)
        let ontoGoal = try rules.move(.right, in: state)
        let crate = EntityRef(id: EntityID(2), kind: .crate)
        #expect(ontoGoal.events == [
            .objectPushed(
                crate,
                from: GridPosition(column: 3, row: 1),
                to: GridPosition(column: 4, row: 1)
            ),
            .entityMoved(
                state.playerRef,
                from: GridPosition(column: 2, row: 1),
                to: GridPosition(column: 3, row: 1)
            ),
            .crateEnteredGoal(crate, at: GridPosition(column: 4, row: 1), completed: 1, total: 1),
            .levelCompleted,
        ])
        #expect(ontoGoal.outcome == .terminal(.completed))
        #expect(ontoGoal.state.status == .completed)
        #expect(ontoGoal.state.moveCount == 1)
        #expect(ontoGoal.state.pushCount == 1)
    }

    @Test("crate leaving a goal emits crateLeftGoal")
    func leaveGoal() throws {
        // Two goals / two crates so the level is not already completed at start.
        let leaveStart = try start("""
            ########
            # @* .$#
            ########
            """)
        #expect(leaveStart.status == .playing)
        let leave = try rules.move(.right, in: leaveStart)
        let leaveCrate = EntityRef(id: EntityID(2), kind: .crate)
        #expect(leave.events == [
            .objectPushed(
                leaveCrate,
                from: GridPosition(column: 3, row: 1),
                to: GridPosition(column: 4, row: 1)
            ),
            .entityMoved(
                leaveStart.playerRef,
                from: GridPosition(column: 2, row: 1),
                to: GridPosition(column: 3, row: 1)
            ),
            .crateLeftGoal(leaveCrate, at: GridPosition(column: 3, row: 1), completed: 0, total: 2),
        ])
        #expect(leave.outcome == .changed)
        #expect(leave.state.status == .playing)
    }

    @Test("input after completion is rejected without mutation or fault")
    func terminalInputRejected() throws {
        let state = try start("""
            ######
            # @$.#
            ######
            """)
        let won = try rules.move(.right, in: state)
        #expect(won.state.status == .completed)

        let after = try rules.move(.left, in: won.state)
        #expect(after.outcome == .blocked)
        #expect(after.events.isEmpty)
        #expect(after.state == won.state)
    }

    @Test("identical input sequences are deterministic")
    func deterministicReplay() throws {
        let ascii = """
            #####
            # @ #
            #   #
            # $ #
            # . #
            #####
            """
        let moves: [Direction] = [.down, .down]
        func run() throws -> (SokobanState, [[GameEvent]]) {
            var state = try start(ascii)
            var eventLog: [[GameEvent]] = []
            for direction in moves {
                let transition = try rules.move(direction, in: state)
                eventLog.append(transition.events)
                state = transition.state
            }
            return (state, eventLog)
        }
        let first = try run()
        let second = try run()
        #expect(first.0 == second.0)
        #expect(first.1 == second.1)
        #expect(first.0.status == .completed)
        #expect(first.0.moveCount == 2)
        #expect(first.0.pushCount == 1)
    }
}
