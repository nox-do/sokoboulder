import Testing
@testable import GameCore

@Suite("Sokoban checkpoint contract")
struct SokobanCheckpointTests {
    private let rules = SokobanRules()

    @Test("ruleVersion is 1")
    func ruleVersionIsOne() {
        #expect(SokobanRules.ruleVersion == 1)
    }

    @Test("checkpoint round-trip restores identical state")
    func checkpointRoundTrip() throws {
        let level = try SokobanLevelValidator.level(
            fromASCII: """
                #######
                #     #
                # # $ #
                # @ . #
                #######
                """
        )
        var state = try rules.start(level: level)
        state = try rules.move(.right, in: state).state
        state = try rules.move(.up, in: state).state

        let checkpoint = rules.checkpoint(from: state)
        #expect(checkpoint.crates.map(\.id.rawValue) == [2])
        #expect(checkpoint.crates == checkpoint.crates.sorted { $0.id.rawValue < $1.id.rawValue })

        let restored = try rules.restore(level: level, checkpoint: checkpoint)
        #expect(restored == state)
    }

    @Test("restore rejects non-canonical crate IDs")
    func rejectsWrongIDs() throws {
        let level = try SokobanLevelValidator.level(fromASCII: "#@$.#")
        let start = try rules.start(level: level)
        var checkpoint = rules.checkpoint(from: start)
        checkpoint = SokobanCheckpoint(
            playerPosition: checkpoint.playerPosition,
            crates: [SokobanCratePlacement(id: EntityID(99), position: checkpoint.crates[0].position)],
            moveCount: 0,
            pushCount: 0,
            status: .playing
        )
        #expect(throws: EngineFault.self) {
            try rules.restore(level: level, checkpoint: checkpoint)
        }
    }

    @Test("restore rejects unsorted crates")
    func rejectsUnsortedCrates() throws {
        let level = try SokobanLevelValidator.level(
            fromASCII: """
                ######
                #@   #
                # $$ #
                #  ..#
                ######
                """
        )
        let start = try rules.start(level: level)
        let sorted = rules.checkpoint(from: start)
        #expect(sorted.crates.count == 2)
        let unsorted = SokobanCheckpoint(
            playerPosition: sorted.playerPosition,
            crates: Array(sorted.crates.reversed()),
            moveCount: 0,
            pushCount: 0,
            status: .playing
        )
        #expect(throws: EngineFault.self) {
            try rules.restore(level: level, checkpoint: unsorted)
        }
    }
}
