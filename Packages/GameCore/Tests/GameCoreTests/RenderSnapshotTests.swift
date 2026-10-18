import Testing

@testable import GameCore

@Suite("RenderSnapshot")
struct RenderSnapshotTests {
    @Test("projects terrain, player, crates, and counters in row-major order")
    func projectsSokobanState() throws {
        let level = try SokobanLevelValidator.level(
            fromASCII:
                """
                #####
                #@$.#
                #####
                """
        )
        let state = try SokobanRules().start(level: level)
        let snapshot = RenderSnapshot.project(state)

        #expect(snapshot.width == 5)
        #expect(snapshot.height == 3)
        #expect(snapshot.cells.count == 15)
        #expect(snapshot.metrics.sokoban?.moveCount == 0)
        #expect(snapshot.metrics.sokoban?.pushCount == 0)
        #expect(snapshot.metrics.sokoban?.completedGoalCount == 0)
        #expect(snapshot.metrics.sokoban?.totalGoalCount == 1)
        #expect(snapshot.status == .playing)

        #expect(snapshot.player.ref == EntityRef(id: EntityID(1), kind: .player))
        #expect(snapshot.player.position == GridPosition(column: 1, row: 1))
        #expect(snapshot.entities.count == 1)
        #expect(snapshot.entities[0].ref == EntityRef(id: EntityID(2), kind: .crate))
        #expect(snapshot.entities[0].position == GridPosition(column: 2, row: 1))

        #expect(snapshot.cell(at: GridPosition(column: 0, row: 0))?.terrain == .wall)
        #expect(snapshot.cell(at: GridPosition(column: 1, row: 1))?.terrain == .floor)
        #expect(snapshot.cell(at: GridPosition(column: 2, row: 1))?.terrain == .floor)
        #expect(snapshot.cell(at: GridPosition(column: 3, row: 1))?.terrain == .goal)
        #expect(snapshot.index(of: GridPosition(column: 3, row: 1)) == 1 * 5 + 3)
        #expect(snapshot.cell(at: GridPosition(column: -1, row: 0)) == nil)
        #expect(snapshot.index(of: GridPosition(column: 5, row: 0)) == nil)
    }

    @Test("player is not duplicated in entities")
    func playerNotInEntities() throws {
        let level = try SokobanLevelValidator.level(
            fromASCII:
                """
                ####
                #@$#
                # .#
                ####
                """
        )
        let snapshot = RenderSnapshot.project(try SokobanRules().start(level: level))
        #expect(snapshot.entities.allSatisfy { $0.ref.kind == .crate })
        #expect(snapshot.entities.contains { $0.ref.id == snapshot.player.ref.id } == false)
    }

    @Test("projection follows a push and completion")
    func followsPushAndCompletion() throws {
        let level = try SokobanLevelValidator.level(
            fromASCII:
                """
                #####
                #@$.#
                #####
                """
        )
        var state = try SokobanRules().start(level: level)
        let moved = try SokobanRules().move(.right, in: state)
        state = moved.state
        let snapshot = RenderSnapshot.project(state)

        #expect(snapshot.player.position == GridPosition(column: 2, row: 1))
        #expect(snapshot.entities[0].position == GridPosition(column: 3, row: 1))
        #expect(snapshot.metrics.sokoban?.moveCount == 1)
        #expect(snapshot.metrics.sokoban?.pushCount == 1)
        #expect(snapshot.metrics.sokoban?.completedGoalCount == 1)
        #expect(snapshot.metrics.sokoban?.totalGoalCount == 1)
        #expect(snapshot.status == .completed)
        #expect(snapshot.cell(at: GridPosition(column: 3, row: 1))?.terrain == .goal)
    }
    @Test("Collecting extra diamonds preserves the level requirement", arguments: [0, 1])
    func extraDiamondsKeepRequirement(required: Int) throws {
        let level = try CaveLevelBuilder.level(
            fromASCII: "#######\n#P** E#\n#######", requiredDiamonds: required
        )
        let rules = CaveRules()
        var state = try rules.start(level: level)
        for _ in 0..<2 { state = try rules.tick(input: .move(.right), state: state).state }
        let metrics = try #require(RenderSnapshot.project(state).metrics.cave)
        #expect(metrics.collectedDiamonds == 2)
        #expect(metrics.requiredDiamonds == required)
    }

}
