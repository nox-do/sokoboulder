import Testing
@testable import GameCore

/// Golden scenarios: ASCII → parse → validate → start → moves → completed.
@Suite("Sokoban golden scenarios")
struct SokobanGoldenTests {
    private let rules = SokobanRules()

    @Test("golden 1: free movement and blockades")
    func freeMovementAndBlockades() throws {
        let level = try SokobanLevelValidator.level(fromASCII: """
            #####
            #   #
            # @ #
            #  .#
            #  $#
            #####
            """)
        var state = try rules.start(level: level)

        for direction in [Direction.left, .up, .right, .right] {
            let transition = try rules.move(direction, in: state)
            #expect(transition.outcome == .changed)
            state = transition.state
        }
        #expect(state.playerPosition == GridPosition(column: 3, row: 1))
        #expect(state.moveCount == 4)

        let blocked = try rules.move(.up, in: state)
        #expect(blocked.outcome == .blocked)
        #expect(blocked.state == state)
        #expect(blocked.events == [.movementBlocked(at: GridPosition(column: 3, row: 0))])
        #expect(state.pushCount == 0)
        #expect(state.status == .playing)
    }

    @Test("golden 2: push onto goal completes; further input ignored")
    func pushOnGoalAndTerminal() throws {
        let level = try SokobanLevelValidator.level(fromASCII: """
            #######
            #  @$.#
            #######
            """)
        var state = try rules.start(level: level)
        let crate = EntityRef(id: EntityID(2), kind: .crate)

        let onto = try rules.move(.right, in: state)
        #expect(onto.events == [
            .objectPushed(
                crate,
                from: GridPosition(column: 4, row: 1),
                to: GridPosition(column: 5, row: 1)
            ),
            .entityMoved(
                state.playerRef,
                from: GridPosition(column: 3, row: 1),
                to: GridPosition(column: 4, row: 1)
            ),
            .crateEnteredGoal(crate, at: GridPosition(column: 5, row: 1), completed: 1, total: 1),
            .levelCompleted,
        ])
        #expect(onto.outcome == .terminal(.completed))
        state = onto.state

        let ignored = try rules.move(.left, in: state)
        #expect(ignored.state == state)
        #expect(ignored.events.isEmpty)
        #expect(ignored.outcome == .blocked)
    }

    @Test("golden 3: full solvable level — parse → validate → start → moves → completed")
    func fullSolvableLevel() throws {
        let ascii = """
            #####
            #@  #
            # $ #
            # . #
            #####
            """
        let map = try SokobanASCIIParser.parse(ascii)
        let level = try SokobanLevelValidator.validate(map)
        var state = try rules.start(level: level)

        let sequence: [Direction] = [.right, .down]
        var allEvents: [GameEvent] = []

        for direction in sequence {
            let transition = try rules.move(direction, in: state)
            allEvents.append(contentsOf: transition.events)
            #expect(transition.outcome != .blocked)
            state = transition.state
        }

        #expect(state.status == .completed)
        #expect(state.moveCount == 2)
        #expect(state.pushCount == 1)
        #expect(state.playerPosition == GridPosition(column: 2, row: 2))
        #expect(state.grid[GridPosition(column: 2, row: 3)].occupant == .crate(EntityID(2)))
        #expect(state.completedGoalCount == 1)

        let player = EntityRef(id: EntityID(1), kind: .player)
        let crate = EntityRef(id: EntityID(2), kind: .crate)
        #expect(allEvents == [
            .entityMoved(player, from: GridPosition(column: 1, row: 1), to: GridPosition(column: 2, row: 1)),
            .objectPushed(crate, from: GridPosition(column: 2, row: 2), to: GridPosition(column: 2, row: 3)),
            .entityMoved(player, from: GridPosition(column: 2, row: 1), to: GridPosition(column: 2, row: 2)),
            .crateEnteredGoal(crate, at: GridPosition(column: 2, row: 3), completed: 1, total: 1),
            .levelCompleted,
        ])
    }
}
