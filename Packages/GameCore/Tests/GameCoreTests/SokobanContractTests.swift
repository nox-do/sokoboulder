import Testing
@testable import GameCore

@Suite("Sokoban contract guards")
struct SokobanContractTests {
    private let rules = SokobanRules()

    @Test("already-solved level starts completed")
    func alreadySolvedStartsCompleted() throws {
        let level = try SokobanLevelValidator.level(fromASCII: "#@*#")
        let state = try rules.start(level: level)
        #expect(state.status == .completed)
        #expect(state.allGoalsCompleted)
        #expect(state.moveCount == 0)
        #expect(state.pushCount == 0)

        let after = try rules.move(.left, in: state)
        #expect(after.outcome == .blocked)
        #expect(after.events.isEmpty)
        #expect(after.state == state)
    }

    @Test("start rejects crate outside grid")
    func startRejectsCrateOutsideGrid() {
        let level = SokobanLevel(
            terrain: Grid(width: 2, height: 1, cells: [.floor, .goal]),
            playerStart: GridPosition(column: 0, row: 0),
            crateStarts: [GridPosition(column: 5, row: 0)]
        )
        #expect(throws: EngineFault.self) {
            try rules.start(level: level)
        }
    }

    @Test("start rejects crate on wall")
    func startRejectsCrateOnWall() {
        let level = SokobanLevel(
            terrain: Grid(width: 3, height: 1, cells: [.floor, .wall, .goal]),
            playerStart: GridPosition(column: 0, row: 0),
            crateStarts: [GridPosition(column: 1, row: 0)]
        )
        #expect(throws: EngineFault.self) {
            try rules.start(level: level)
        }
    }

    @Test("start rejects unsorted crateStarts")
    func startRejectsUnsortedCrates() {
        let level = SokobanLevel(
            terrain: Grid(width: 4, height: 1, cells: [.floor, .goal, .goal, .floor]),
            playerStart: GridPosition(column: 0, row: 0),
            crateStarts: [
                GridPosition(column: 2, row: 0),
                GridPosition(column: 1, row: 0),
            ]
        )
        #expect(throws: EngineFault.self) {
            try rules.start(level: level)
        }
    }

    @Test("start rejects crate/goal mismatch")
    func startRejectsCrateGoalMismatch() {
        let level = SokobanLevel(
            terrain: Grid(width: 4, height: 1, cells: [.floor, .floor, .floor, .goal]),
            playerStart: GridPosition(column: 0, row: 0),
            crateStarts: [
                GridPosition(column: 1, row: 0),
                GridPosition(column: 2, row: 0),
            ]
        )
        #expect(throws: EngineFault.self) {
            try rules.start(level: level)
        }
    }

    @Test("move throws EngineFault for corrupt state before terminal short-circuit")
    func moveRejectsCorruptState() throws {
        let level = try SokobanLevelValidator.level(fromASCII: """
            ####
            #@$#
            # .#
            ####
            """)
        var state = try rules.start(level: level)
        state.moveCount = -1

        #expect(throws: EngineFault.self) {
            try rules.move(.right, in: state)
        }
    }

    @Test("move throws EngineFault when player sits on a wall")
    func moveRejectsPlayerOnWall() throws {
        let level = try SokobanLevelValidator.level(fromASCII: """
            ####
            #@$#
            # .#
            ####
            """)
        var state = try rules.start(level: level)
        state.playerPosition = GridPosition(column: 0, row: 0)

        #expect(throws: EngineFault.self) {
            try rules.move(.right, in: state)
        }
    }

    @Test("completed corrupt status still faults before ignore-path")
    func completedCorruptStillFaults() throws {
        let level = try SokobanLevelValidator.level(fromASCII: "#@*#")
        var state = try rules.start(level: level)
        #expect(state.status == .completed)
        state.pushCount = 3
        state.moveCount = 1

        #expect(throws: EngineFault.self) {
            try rules.move(.left, in: state)
        }
    }

    @Test("playing with all goals filled is an EngineFault")
    func playingWithAllGoalsFilledFaults() throws {
        let level = try SokobanLevelValidator.level(fromASCII: "#@*#")
        var state = try rules.start(level: level)
        #expect(state.status == .completed)
        #expect(state.allGoalsCompleted)
        state.status = .playing

        #expect(throws: EngineFault.self) {
            try rules.move(.left, in: state)
        }
    }

    @Test("crate IDs are assigned in row-major grid order")
    func rowMajorCrateIDs() throws {
        let level = try SokobanLevelValidator.level(fromASCII: """
            #####
            #@$$#
            #.. #
            #####
            """)
        let state = try rules.start(level: level)
        #expect(state.grid[GridPosition(column: 2, row: 1)].occupant == .crate(EntityID(2)))
        #expect(state.grid[GridPosition(column: 3, row: 1)].occupant == .crate(EntityID(3)))
    }
}
