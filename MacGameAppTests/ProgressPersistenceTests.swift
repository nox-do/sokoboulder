import Foundation
import Testing
@testable import MacGameApp

@Suite("Progress persistence")
@MainActor
struct ProgressPersistenceTests {
    @Test("completion keeps unlocks across content hash changes")
    func completionKeepsStableIDProgressAcrossHashChanges() throws {
        let configuration = try ProgressPersistence.Configuration.ephemeral()
        let first = "level.001"
        let persistence = ProgressPersistence(configuration: configuration, firstLevelID: first)

        _ = persistence.recordCompletion(
            levelID: first,
            contentHash: "old-hash",
            ruleVersion: 1,
            moveCount: 12,
            pushCount: 4,
            nextLevelID: "level.002"
        )
        let delta = persistence.recordCompletion(
            levelID: first,
            contentHash: "new-hash",
            ruleVersion: 1,
            moveCount: 10,
            pushCount: 3,
            nextLevelID: "level.002"
        )

        #expect(persistence.file.isCompleted(first))
        #expect(persistence.file.isUnlocked("level.002"))
        #expect(delta.newlyCompleted == false)
        #expect(persistence.file.records.count == 2)
        #expect(persistence.file.record(levelID: first, contentHash: "old-hash", ruleVersion: 1)?.bestMoveCount == 12)
        #expect(persistence.file.record(levelID: first, contentHash: "new-hash", ruleVersion: 1)?.bestMoveCount == 10)
    }

    @Test("completion remains persisted independently of later undo")
    func completionSurvivesUndoConceptually() throws {
        let configuration = try ProgressPersistence.Configuration.ephemeral()
        let persistence = ProgressPersistence(configuration: configuration, firstLevelID: "level.001")
        _ = persistence.recordCompletion(
            levelID: "level.001",
            contentHash: "hash",
            ruleVersion: 1,
            moveCount: 5,
            pushCount: 2,
            nextLevelID: "level.002"
        )

        let reloaded = ProgressPersistence(configuration: configuration, firstLevelID: "level.001")
        #expect(reloaded.file.isCompleted("level.001"))
        #expect(reloaded.file.isUnlocked("level.002"))
    }

    @Test("atomic codec round-trips progress")
    func atomicRoundTrip() throws {
        let configuration = try ProgressPersistence.Configuration.ephemeral()
        let original = ProgressFileV1(
            schemaVersion: ProgressFileV1.currentSchemaVersion,
            unlockedLevelIDs: ["level.001", "level.002"],
            completedLevelIDs: ["level.001"],
            lastSelectedLevelID: "level.002",
            seenTutorialHintIDs: ["hint.001"],
            records: []
        )

        try ProgressFileCodec.atomicWrite(original, to: configuration.fileURL)
        let data = try Data(contentsOf: configuration.fileURL)
        #expect(try ProgressFileCodec.decode(data) == original)
    }

    @Test("fresh campaign requires no completion or extra unlock")
    func freshCampaignDetection() {
        #expect(ProgressFileV1.fresh(firstLevelID: "level.001").isFreshCampaign)

        var completed = ProgressFileV1.fresh(firstLevelID: "level.001")
        completed.completedLevelIDs = ["level.001"]
        #expect(!completed.isFreshCampaign)

        var unlocked = ProgressFileV1.fresh(firstLevelID: "level.001")
        unlocked.unlockedLevelIDs.append("level.002")
        #expect(!unlocked.isFreshCampaign)
    }

    @Test("newer progress schema keeps the original file and disables writes")
    func newerSchemaPreservesOriginalAndDisablesWrites() throws {
        let configuration = try ProgressPersistence.Configuration.ephemeral()
        let v2 = """
            {
              "schemaVersion": 2,
              "unlockedLevelIDs": ["future.level"],
              "completedLevelIDs": ["future.level"],
              "lastSelectedLevelID": "future.level",
              "seenTutorialHintIDs": [],
              "records": [],
              "futureField": true
            }
            """
        let originalData = Data(v2.utf8)
        try originalData.write(to: configuration.fileURL)

        let persistence = ProgressPersistence(
            configuration: configuration,
            firstLevelID: "level.001"
        )
        #expect(!persistence.isEnabled)
        #expect(persistence.disabledReason != nil)
        #expect(persistence.loadDiagnostic != nil)
        #expect(persistence.file.isFreshCampaign)

        _ = persistence.recordCompletion(
            levelID: "level.001",
            contentHash: "hash",
            ruleVersion: 1,
            moveCount: 1,
            pushCount: 1,
            nextLevelID: "level.002"
        )

        let onDisk = try Data(contentsOf: configuration.fileURL)
        #expect(onDisk == originalData)
        #expect(ProgressFileCodec.peekSchemaVersion(onDisk) == 2)
    }
}
