import Foundation
import Testing
@testable import GameCore
@testable import MacGameApp

@Suite("Sokoban run writer")
@MainActor
struct SokobanRunWriterTests {
    @Test("older generation never overwrites a newer committed write")
    func olderGenerationIgnored() async throws {
        let configuration = try SokobanRunStoreConfiguration.ephemeral()
        let writer = SokobanRunWriter(fileURL: configuration.fileURL)

        let descriptor = try #require(SokobanLevelCatalog.descriptor(id: "sokoban.tutorial.001"))
        let checkpoint = try SokobanCheckpointV1(
            semantic: SokobanRules().checkpoint(
                from: try SokobanRules().start(level: descriptor.makeLevel())
            )
        )
        let newer = SokobanRunFileV1(
            schemaVersion: 1,
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            ruleVersion: 1,
            checkpoint: checkpoint,
            commands: [.right],
            cursor: 1
        )
        let older = SokobanRunFileV1(
            schemaVersion: 1,
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            ruleVersion: 1,
            checkpoint: checkpoint,
            commands: [],
            cursor: 0
        )

        await writer.enqueue(generation: 2, file: newer)
        await writer.enqueue(generation: 1, file: older)
        await writer.flush()

        let data = try Data(contentsOf: configuration.fileURL)
        let loaded = try SokobanRunFileCodec.decode(data)
        #expect(loaded.commands == [.right])
        #expect(await writer.committedGeneration() == 2)
    }

    @Test("failed atomic write keeps the last valid file")
    func failedWriteKeepsPrevious() async throws {
        let configuration = try SokobanRunStoreConfiguration.ephemeral()
        let descriptor = try #require(SokobanLevelCatalog.descriptor(id: "sokoban.tutorial.001"))
        let checkpoint = try SokobanCheckpointV1(
            semantic: SokobanRules().checkpoint(
                from: try SokobanRules().start(level: descriptor.makeLevel())
            )
        )
        let valid = SokobanRunFileV1(
            schemaVersion: 1,
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            ruleVersion: 1,
            checkpoint: checkpoint,
            commands: [.right],
            cursor: 1
        )
        try SokobanRunWriter.atomicWrite(file: valid, to: configuration.fileURL)
        let before = try Data(contentsOf: configuration.fileURL)

        // Point the write at a path whose parent is a regular file → I/O failure.
        let blocker = configuration.directoryURL.appendingPathComponent("not-a-dir")
        try Data("x".utf8).write(to: blocker)
        let badURL = blocker.appendingPathComponent("sokoban-run-v1.json")

        var didThrow = false
        do {
            try SokobanRunWriter.atomicWrite(file: valid, to: badURL)
        } catch is SokobanRunWriteError {
            didThrow = true
        } catch {
            didThrow = true
        }
        #expect(didThrow)

        let after = try Data(contentsOf: configuration.fileURL)
        #expect(after == before)
        let loaded = try SokobanRunFileCodec.decode(after)
        #expect(loaded.commands == [.right])
    }

    @Test("load treats missing file as absent and damaged JSON as invalid backup")
    func loadOutcomes() throws {
        let persistence = try SokobanRunPersistence.ephemeral()
        #expect(persistence.load() == .absent)

        let url = try #require(persistence.configuration).fileURL
        try Data("{not-json".utf8).write(to: url)
        let outcome = persistence.load()
        guard case .invalid(let message, let preserved) = outcome else {
            Issue.record("expected invalid")
            return
        }
        #expect(message.contains("damaged") || message.contains("JSON"))
        #expect(preserved)
        #expect(!FileManager.default.fileExists(atPath: url.path))

        // Newer schema: keep original in place.
        let persistence2 = try SokobanRunPersistence.ephemeral()
        let newerURL = try #require(persistence2.configuration).fileURL
        let newer = """
            {
              "schemaVersion" : 99,
              "levelID" : "x",
              "contentHash" : "y",
              "ruleVersion" : 1,
              "checkpoint" : {
                "schemaVersion" : 1,
                "playerColumn" : 0,
                "playerRow" : 0,
                "crates" : [],
                "moveCount" : 0,
                "pushCount" : 0,
                "status" : "playing"
              },
              "commands" : [],
              "cursor" : 0
            }
            """
        try Data(newer.utf8).write(to: newerURL)
        let newerOutcome = persistence2.load()
        guard case .invalid(_, let preservedOriginal) = newerOutcome else {
            Issue.record("expected invalid for newer schema")
            return
        }
        #expect(preservedOriginal)
        #expect(FileManager.default.fileExists(atPath: newerURL.path))

        // Older schema: quarantine (backup + remove active file).
        let persistence3 = try SokobanRunPersistence.ephemeral()
        let olderURL = try #require(persistence3.configuration).fileURL
        let older = """
            {
              "schemaVersion" : 0,
              "levelID" : "x",
              "contentHash" : "y",
              "ruleVersion" : 1,
              "checkpoint" : {
                "schemaVersion" : 1,
                "playerColumn" : 0,
                "playerRow" : 0,
                "crates" : [],
                "moveCount" : 0,
                "pushCount" : 0,
                "status" : "playing"
              },
              "commands" : [],
              "cursor" : 0
            }
            """
        try Data(older.utf8).write(to: olderURL)
        let olderOutcome = persistence3.load()
        guard case .invalid(let olderMessage, let olderPreserved) = olderOutcome else {
            Issue.record("expected invalid for older schema")
            return
        }
        #expect(olderMessage.contains("outdated"))
        #expect(olderPreserved)
        #expect(!FileManager.default.fileExists(atPath: olderURL.path))
    }

    @Test("rapid enqueues coalesce to the newest generation")
    func enqueuesCoalesce() async throws {
        let configuration = try SokobanRunStoreConfiguration.ephemeral()
        let writer = SokobanRunWriter(fileURL: configuration.fileURL)
        let descriptor = try #require(SokobanLevelCatalog.descriptor(id: "sokoban.tutorial.001"))
        let checkpoint = try SokobanCheckpointV1(
            semantic: SokobanRules().checkpoint(
                from: try SokobanRules().start(level: descriptor.makeLevel())
            )
        )

        func file(commands: [SokobanDirectionV1], cursor: Int) -> SokobanRunFileV1 {
            SokobanRunFileV1(
                schemaVersion: 1,
                levelID: descriptor.id,
                contentHash: descriptor.contentHash,
                ruleVersion: 1,
                checkpoint: checkpoint,
                commands: commands,
                cursor: cursor
            )
        }

        await writer.enqueue(generation: 1, file: file(commands: [], cursor: 0))
        await writer.enqueue(generation: 2, file: file(commands: [.left], cursor: 1))
        await writer.enqueue(generation: 3, file: file(commands: [.left, .right], cursor: 2))
        await writer.flush()

        let loaded = try SokobanRunFileCodec.decode(try Data(contentsOf: configuration.fileURL))
        #expect(loaded.commands == [.left, .right])
        #expect(loaded.cursor == 2)
        #expect(await writer.committedGeneration() == 3)
    }

    @Test("cached synchronous write persists without actor flush")
    func cachedSyncWrite() throws {
        let persistence = try SokobanRunPersistence.ephemeral()
        let descriptor = try #require(SokobanLevelCatalog.descriptor(id: "sokoban.tutorial.001"))
        let checkpoint = try SokobanCheckpointV1(
            semantic: SokobanRules().checkpoint(
                from: try SokobanRules().start(level: descriptor.makeLevel())
            )
        )
        let file = SokobanRunFileV1(
            schemaVersion: 1,
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            ruleVersion: 1,
            checkpoint: checkpoint,
            commands: [.right],
            cursor: 1
        )
        persistence.scheduleSave(file)
        persistence.writeCachedRunSynchronously()

        let url = try #require(persistence.configuration).fileURL
        let loaded = try SokobanRunFileCodec.decode(try Data(contentsOf: url))
        #expect(loaded.commands == [.right])
    }

    @Test("flush enqueues the cached generation before waiting on the writer")
    func flushEnqueuesCachedGeneration() async throws {
        let persistence = try SokobanRunPersistence.ephemeral()
        let descriptor = try #require(SokobanLevelCatalog.descriptor(id: "sokoban.tutorial.001"))
        let checkpoint = try SokobanCheckpointV1(
            semantic: SokobanRules().checkpoint(
                from: try SokobanRules().start(level: descriptor.makeLevel())
            )
        )

        func makeFile(commands: [SokobanDirectionV1]) -> SokobanRunFileV1 {
            SokobanRunFileV1(
                schemaVersion: 1,
                levelID: descriptor.id,
                contentHash: descriptor.contentHash,
                ruleVersion: 1,
                checkpoint: checkpoint,
                commands: commands,
                cursor: commands.count
            )
        }

        // Older generation may start writing; newest stays in the cache while its
        // fire-and-forget enqueue Task has not necessarily reached the actor yet.
        persistence.scheduleSave(makeFile(commands: [.left]))
        persistence.scheduleSave(makeFile(commands: [.left, .right]))

        await persistence.flush()

        let url = try #require(persistence.configuration).fileURL
        let loaded = try SokobanRunFileCodec.decode(try Data(contentsOf: url))
        #expect(loaded.commands == [.left, .right])
        #expect(loaded.cursor == 2)
    }

    @Test("disabled persistence does not write and reports a reason")
    func disabledStore() {
        let persistence = SokobanRunPersistence.disabled(reason: "no folder")
        #expect(!persistence.isEnabled)
        #expect(persistence.disabledReason == "no folder")
        #expect(persistence.load() == .absent)
        #expect(persistence.configuration == nil)
    }

    @Test("oversized file is rejected before decode")
    func rejectsOversized() throws {
        let huge = Data(repeating: 0x61, count: SokobanRunFileCodec.maxFileByteCount + 1)
        #expect(throws: SokobanRunCodecError.fileTooLarge(byteCount: huge.count)) {
            try SokobanRunFileCodec.decode(huge)
        }
    }
}
