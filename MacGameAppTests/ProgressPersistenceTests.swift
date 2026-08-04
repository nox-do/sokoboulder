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
            records: [],
            unlockedCaveLevelIDs: ["cave.001"],
            completedCaveLevelIDs: [],
            lastSelectedCaveLevelID: "cave.001",
            caveRecords: []
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

    @Test("resetToFresh clears campaign progress on disk")
    func resetToFreshPersists() throws {
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
        persistence.markHintSeen("hint.001")
        #expect(!persistence.file.isFreshCampaign)

        persistence.resetToFresh(firstLevelID: "level.001")
        #expect(persistence.file.isFreshCampaign)
        #expect(persistence.file.seenTutorialHintIDs.isEmpty)

        let reloaded = ProgressPersistence(configuration: configuration, firstLevelID: "level.001")
        #expect(reloaded.file.isFreshCampaign)
        #expect(reloaded.file.unlockedLevelIDs == ["level.001"])
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

    @Test("legacy progress JSON without cave keys still decodes")
    func legacyProgressDecodesWithEmptyCaveFields() throws {
        let configuration = try ProgressPersistence.Configuration.ephemeral()
        let legacy = """
            {
              "schemaVersion": 1,
              "unlockedLevelIDs": ["level.001"],
              "completedLevelIDs": [],
              "lastSelectedLevelID": "level.001",
              "seenTutorialHintIDs": [],
              "records": []
            }
            """
        try Data(legacy.utf8).write(to: configuration.fileURL)

        let persistence = ProgressPersistence(
            configuration: configuration,
            firstLevelID: "level.001",
            caveTutorialLevelIDs: ["cave.demo.001", "cave.demo.002", "cave.demo.003"]
        )
        #expect(persistence.file.unlockedLevelIDs == ["level.001"])
        #expect(persistence.file.unlockedCaveLevelIDs == [
            "cave.demo.001",
            "cave.demo.002",
            "cave.demo.003",
        ])
        #expect(persistence.isFreshCaveCampaign)
    }

    @Test("cave completion unlocks next level and tracks score highs")
    func caveCompletionUnlocksAndRecords() throws {
        let tutorials = ["cave.demo.001", "cave.demo.002", "cave.demo.003"]
        let persistence = try ProgressPersistence.ephemeral(
            firstLevelID: "level.001",
            caveTutorialLevelIDs: tutorials
        )
        #expect(persistence.isFreshCaveCampaign)
        #expect(persistence.file.isCaveUnlocked("cave.demo.003"))
        #expect(!persistence.file.isCaveUnlocked("cave.demo.004"))

        let delta = persistence.recordCaveCompletion(
            levelID: "cave.demo.003",
            contentHash: "hash-a",
            ruleVersion: 1,
            score: 120,
            remainingTicks: 40,
            nextLevelID: "cave.demo.004"
        )
        #expect(delta.newlyCompleted)
        #expect(delta.unlockedLevelID == "cave.demo.004")
        #expect(persistence.file.isCaveUnlocked("cave.demo.004"))
        #expect(!persistence.isFreshCaveCampaign)
        #expect(delta.bestScore == 120)
        #expect(delta.bestRemainingTicks == 40)

        let worse = persistence.recordCaveCompletion(
            levelID: "cave.demo.003",
            contentHash: "hash-a",
            ruleVersion: 1,
            score: 50,
            remainingTicks: 10,
            nextLevelID: "cave.demo.004"
        )
        #expect(!worse.newBestScore)
        #expect(!worse.newBestRemainingTicks)
        #expect(worse.bestScore == 120)

        let better = persistence.recordCaveCompletion(
            levelID: "cave.demo.003",
            contentHash: "hash-a",
            ruleVersion: 1,
            score: 200,
            remainingTicks: 55,
            nextLevelID: "cave.demo.004"
        )
        #expect(better.newBestScore)
        #expect(better.newBestRemainingTicks)
        #expect(better.bestScore == 200)
    }

    @Test("cheat unlocks all cave levels")
    func unlockAllCaveLevels() throws {
        let tutorials = ["cave.demo.001", "cave.demo.002", "cave.demo.003"]
        let persistence = try ProgressPersistence.ephemeral(
            firstLevelID: "level.001",
            caveTutorialLevelIDs: tutorials
        )
        persistence.unlockAllCaveLevels([
            "cave.demo.001",
            "cave.demo.002",
            "cave.demo.003",
            "cave.demo.004",
            "cave.demo.005",
        ])
        #expect(persistence.file.isCaveUnlocked("cave.demo.005"))
        #expect(!persistence.isFreshCaveCampaign)
    }

    @Test("sokoban reset preserves cave progress")
    func sokobanResetKeepsCave() throws {
        let tutorials = ["cave.demo.001"]
        let persistence = try ProgressPersistence.ephemeral(
            firstLevelID: "level.001",
            caveTutorialLevelIDs: tutorials
        )
        _ = persistence.recordCaveCompletion(
            levelID: "cave.demo.001",
            contentHash: "h",
            ruleVersion: 1,
            score: 10,
            remainingTicks: 5,
            nextLevelID: "cave.demo.002"
        )
        persistence.resetToFresh(firstLevelID: "level.001")
        #expect(persistence.file.isFreshCampaign)
        #expect(persistence.file.isCaveCompleted("cave.demo.001"))
        #expect(persistence.file.isCaveUnlocked("cave.demo.002"))
    }
}
