import Foundation
import Testing
@testable import GameCore
@testable import MacGameApp

@MainActor
private final class RecordingSaveSink: SokobanRunSaveSink {
    private(set) var saves: [SokobanRunFileV1] = []

    func scheduleSave(_ file: SokobanRunFileV1) {
        saves.append(file)
    }

    var last: SokobanRunFileV1? { saves.last }
}

@Suite("Sokoban run file V1")
@MainActor
struct SokobanRunFileV1Tests {
    private func level001Descriptor() throws -> SokobanLevelDescriptor {
        try #require(SokobanLevelCatalog.descriptor(id: "sokoban.tutorial.001"))
    }

    private func makeFreshSession(
        ascii: String = """
            #####
            #@$.#
            #####
            """,
        levelID: String = "test.level",
        contentHash: String = "hash",
        sink: SokobanRunSaveSink? = nil
    ) throws -> GameSession {
        let level = try SokobanLevelValidator.level(fromASCII: ascii)
        return try GameSession(
            level: level,
            levelID: levelID,
            contentHash: contentHash,
            saveSink: sink
        )
    }

    @Test("golden fixture decodes, restores, and re-encodes byte-identically")
    func goldenRoundTrip() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/SokobanRunFileV1.golden.json")
        let data = try Data(contentsOf: fixtureURL)
        let file = try SokobanRunFileCodec.decode(data)
        let restored = try SokobanRunRestorer.restore(file)
        #expect(restored.currentState.status == .completed)
        #expect(restored.cursor == 3)
        #expect(restored.commands == [.right, .right, .right])
        #expect(restored.undoStack.count == 3)
        #expect(restored.redoStack.isEmpty)

        let reencoded = try SokobanRunFileCodec.encode(file)
        #expect(reencoded == data)
    }

    @Test("encode/decode roundtrip preserves fields")
    func encodeDecodeRoundtrip() throws {
        let descriptor = try level001Descriptor()
        let sink = RecordingSaveSink()
        let session = try GameSession(
            level: descriptor.makeLevel(),
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            saveSink: sink
        )
        _ = session.start()
        _ = session.submitMove(.right)
        let file = try #require(sink.last)
        let data = try SokobanRunFileCodec.encode(file)
        let decoded = try SokobanRunFileCodec.decode(data)
        #expect(decoded == file)
    }

    @Test("restore rebuilds identical snapshot counters and undo/redo order")
    func restoreRebuildsStacks() throws {
        let descriptor = try #require(SokobanLevelCatalog.descriptor(id: "sokoban.tutorial.002"))
        let sink = RecordingSaveSink()
        let session = try GameSession(
            level: descriptor.makeLevel(),
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            saveSink: sink
        )
        _ = session.start()
        for direction in SokobanTutorialSolutions.level002.prefix(3) {
            _ = session.submitMove(direction)
        }
        _ = session.apply(.undo)
        _ = session.apply(.undo)

        let file = try #require(sink.last)
        let restored = try SokobanRunRestorer.restore(file)
        let restoredSession = GameSession(restored: restored, saveSink: nil)
        let emission = restoredSession.start()
        #expect(emission.render.baseRevision == 0)
        #expect(emission.render.targetRevision == 1)
        #expect(emission.render.delivery == .hardResync)
        #expect(restoredSession.undoCount == 1)
        #expect(restoredSession.redoCount == 2)

        // popLast must yield the state immediately after the cursor first.
        _ = restoredSession.apply(.redo)
        #expect(restoredSession.undoCount == 2)
        #expect(restoredSession.redoCount == 1)
        _ = restoredSession.apply(.redo)
        #expect(restoredSession.undoCount == 3)
        #expect(restoredSession.redoCount == 0)
        _ = restoredSession.apply(.undo)
        _ = restoredSession.apply(.undo)
        _ = restoredSession.apply(.undo)
        #expect(restoredSession.undoCount == 0)
        #expect(restoredSession.redoCount == 3)
    }

    @Test("new move after restore+undo discards redo")
    func newMoveDiscardsRedo() throws {
        let ascii = """
            #######
            #  @  #
            #  $  #
            #  .  #
            #######
            """
        let wide = try SokobanLevelValidator.level(fromASCII: ascii)
        let hash = try SokobanContentHasher.sha256Hex(ascii: ascii)
        let sink = RecordingSaveSink()
        let play = try GameSession(level: wide, levelID: "wide", contentHash: hash, saveSink: sink)
        _ = play.start()
        _ = play.submitMove(.left)
        _ = play.submitMove(.right)
        _ = play.submitMove(.right)
        _ = play.apply(.undo)
        let file = try #require(sink.last)
        let restored = try SokobanRunRestorer.restore(file) {
            if $0 == "wide" {
                return try? SokobanLevelDescriptor(
                    id: "wide",
                    titleID: "title.wide",
                    ascii: ascii,
                    tutorialHintID: "hint.test"
                )
            }
            return SokobanLevelCatalog.descriptor(id: $0)
        }
        let again = GameSession(restored: restored)
        _ = again.start()
        #expect(again.redoCount == 1)
        _ = again.apply(.undo)
        #expect(again.redoCount == 2)
        _ = again.submitMove(.left)
        #expect(again.redoCount == 0)
        #expect(again.journalCommandCount == 2)
    }

    @Test("blocked move does not change the run file")
    func blockedDoesNotSave() throws {
        let sink = RecordingSaveSink()
        let session = try makeFreshSession(sink: sink)
        _ = session.start()
        let savesAfterStart = sink.saves.count
        _ = session.submitMove(.up) // wall
        #expect(sink.saves.count == savesAfterStart)
    }

    @Test("terminal move remains undoable after restore")
    func terminalPlusUndoAfterRestore() throws {
        let descriptor = try level001Descriptor()
        let sink = RecordingSaveSink()
        let session = try GameSession(
            level: descriptor.makeLevel(),
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            saveSink: sink
        )
        _ = session.start()
        _ = session.submitMove(.right)
        _ = session.submitMove(.right)
        _ = session.submitMove(.right)
        #expect(session.phase == .outcomePresenting)
        let file = try #require(sink.last)
        let restored = try SokobanRunRestorer.restore(file)
        let again = GameSession(restored: restored)
        _ = again.start()
        #expect(again.phase == .outcomePresenting)
        let result = again.apply(.undo)
        guard case .emitted(let emission) = result else {
            Issue.record("expected undo emission")
            return
        }
        #expect(emission.appTransition == .returnToPlaying)
        #expect(again.phase == .playing)
    }

    @Test("legacy deadlocked run rewinds before the irreversible push")
    func deadlockedRunRewindsOnRestore() throws {
        let descriptor = try #require(
            SokobanLevelCatalog.descriptor(id: "sokoban.tutorial.002")
        )
        let started = try SokobanRules().start(level: descriptor.makeLevel())
        let commands: [SokobanDirectionV1] = [
            .right, .up, .right, .up, .right, .down,
        ]
        let file = SokobanRunFileV1(
            schemaVersion: SokobanRunFileV1.currentSchemaVersion,
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            ruleVersion: SokobanRules.ruleVersion,
            checkpoint: try SokobanCheckpointV1(
                semantic: SokobanRules().checkpoint(from: started)
            ),
            commands: commands,
            cursor: commands.count
        )

        let restored = try SokobanRunRestorer.restore(file)
        #expect(restored.recoveredStaticDeadlock)
        #expect(restored.cursor == 2)
        #expect(restored.commands == commands.prefix(2).map(\.direction))
        #expect(restored.redoStack.isEmpty)
        #expect(restored.currentState.playerPosition == GridPosition(column: 3, row: 2))
        #expect(
            restored.currentState.grid[GridPosition(column: 4, row: 2)].occupant != nil
        )
        #expect(
            restored.currentState.grid[GridPosition(column: 5, row: 2)].occupant == nil
        )
        #expect(
            restored.currentState.grid[GridPosition(column: 5, row: 3)].occupant == nil
        )
    }

    @Test("legacy deadlock is removed from redo history")
    func deadlockedRedoHistoryIsTruncatedOnRestore() throws {
        let descriptor = try #require(
            SokobanLevelCatalog.descriptor(id: "sokoban.tutorial.002")
        )
        let started = try SokobanRules().start(level: descriptor.makeLevel())
        let commands: [SokobanDirectionV1] = [
            .right, .up, .right, .up, .right, .down,
        ]
        let file = SokobanRunFileV1(
            schemaVersion: SokobanRunFileV1.currentSchemaVersion,
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            ruleVersion: SokobanRules.ruleVersion,
            checkpoint: try SokobanCheckpointV1(
                semantic: SokobanRules().checkpoint(from: started)
            ),
            commands: commands,
            cursor: 1
        )

        let restored = try SokobanRunRestorer.restore(file)
        #expect(restored.recoveredStaticDeadlock)
        #expect(restored.cursor == 1)
        #expect(restored.commands == commands.prefix(2).map(\.direction))
        #expect(restored.currentState.playerPosition == GridPosition(column: 3, row: 3))
        #expect(restored.redoStack.count == 1)

        let session = GameSession(restored: restored)
        _ = session.start()
        guard case .emitted(let emission) = session.apply(.redo) else {
            Issue.record("expected the remaining safe redo")
            return
        }
        #expect(session.redoCount == 0)
        #expect(session.apply(.redo) == .ignored)
        #expect(emission.render.snapshot.player.position == GridPosition(column: 3, row: 2))
        #expect(
            emission.render.snapshot.entities.first?.position
                == GridPosition(column: 4, row: 2)
        )
    }

    @Test("restart clears journal and resets checkpoint")
    func restartClearsJournal() throws {
        let sink = RecordingSaveSink()
        let session = try makeFreshSession(sink: sink)
        _ = session.start()
        _ = session.submitMove(.right)
        _ = session.apply(.restart)
        let file = try #require(sink.last)
        #expect(file.commands.isEmpty)
        #expect(file.cursor == 0)
        #expect(file.checkpoint.moveCount == 0)
        #expect(session.undoCount == 0)
        #expect(session.redoCount == 0)
    }

    @Test("1001 commands compact the oldest into the checkpoint")
    func compactionAt1001() throws {
        // Alternate over one free tile so the test exercises journal size,
        // not repeated snapshots of an unnecessarily huge board.
        let ascii = """
            ########
            #@     #
            #   $ .#
            #      #
            ########
            """
        let level = try SokobanLevelValidator.level(fromASCII: ascii)
        let hash = try SokobanContentHasher.sha256Hex(ascii: ascii)
        let sink = RecordingSaveSink()
        let session = try GameSession(
            level: level,
            levelID: "long",
            contentHash: hash,
            saveSink: sink
        )
        _ = session.start()
        for index in 0..<1000 {
            let results = session.submitMove(index.isMultiple(of: 2) ? .right : .left)
            #expect(!results.isEmpty)
        }
        #expect(session.journalCommandCount == 1000)
        #expect(session.undoCount == 1000)

        _ = session.submitMove(.right)
        #expect(session.journalCommandCount == 1000)
        #expect(session.undoCount == 1000)
        #expect(session.journalCursorValue == 1000)
        #expect(session.checkpointForTesting.moveCount == 1)

        let file = try #require(sink.last)
        #expect(file.commands.count == 1000)
        #expect(file.cursor == 1000)
        #expect(file.checkpoint.moveCount == 1)

        let restored = try SokobanRunRestorer.restore(file) { id in
            guard id == "long" else { return nil }
            return try? SokobanLevelDescriptor(
                id: "long",
                titleID: "title.long",
                ascii: ascii,
                tutorialHintID: "hint.long"
            )
        }
        #expect(restored.currentState.moveCount == 1001)
        #expect(restored.undoStack.count == 1000)
    }

    @Test("invalid cursor and too many commands are rejected")
    func rejectsBadCursorAndCount() throws {
        let descriptor = try level001Descriptor()
        var file = SokobanRunFileV1(
            schemaVersion: 1,
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            ruleVersion: SokobanRules.ruleVersion,
            checkpoint: try SokobanCheckpointV1(
                semantic: SokobanRules().checkpoint(from: try SokobanRules().start(level: descriptor.makeLevel()))
            ),
            commands: [.right],
            cursor: 2
        )
        #expect(throws: SokobanRunRestoreFailure.self) {
            try SokobanRunRestorer.restore(file)
        }

        file = SokobanRunFileV1(
            schemaVersion: 1,
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            ruleVersion: SokobanRules.ruleVersion,
            checkpoint: file.checkpoint,
            commands: Array(repeating: .left, count: 1001),
            cursor: 0
        )
        #expect(throws: SokobanRunRestoreFailure.self) {
            try SokobanRunRestorer.restore(file)
        }
    }

    @Test("wrong hash and rule version are rejected")
    func rejectsHashAndRuleVersion() throws {
        let descriptor = try level001Descriptor()
        let checkpoint = try SokobanCheckpointV1(
            semantic: SokobanRules().checkpoint(from: try SokobanRules().start(level: descriptor.makeLevel()))
        )
        let badHash = SokobanRunFileV1(
            schemaVersion: 1,
            levelID: descriptor.id,
            contentHash: "deadbeef",
            ruleVersion: SokobanRules.ruleVersion,
            checkpoint: checkpoint,
            commands: [],
            cursor: 0
        )
        #expect(throws: SokobanRunRestoreFailure.self) {
            try SokobanRunRestorer.restore(badHash)
        }

        let badRules = SokobanRunFileV1(
            schemaVersion: 1,
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            ruleVersion: SokobanRules.ruleVersion + 1,
            checkpoint: checkpoint,
            commands: [],
            cursor: 0
        )
        #expect(throws: SokobanRunRestoreFailure.self) {
            try SokobanRunRestorer.restore(badRules)
        }
    }

    @Test("unknown newer schema is rejected without needing restore replay")
    func rejectsNewerSchema() throws {
        let descriptor = try level001Descriptor()
        let file = SokobanRunFileV1(
            schemaVersion: 99,
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            ruleVersion: SokobanRules.ruleVersion,
            checkpoint: try SokobanCheckpointV1(
                semantic: SokobanRules().checkpoint(from: try SokobanRules().start(level: descriptor.makeLevel()))
            ),
            commands: [],
            cursor: 0
        )
        #expect(throws: SokobanRunRestoreFailure.unknownSchemaVersion(99)) {
            try SokobanRunRestorer.restore(file)
        }
    }
}
