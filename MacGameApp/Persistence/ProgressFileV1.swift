import Foundation
import GameCore

/// Versioned campaign progress (schema 1).
///
/// Unlock / “ever completed” keys use stable level IDs only. Best scores are
/// keyed by level ID + content hash + rule version so revised geometry does not
/// inherit old records or revoke unlocks.
struct ProgressFileV1: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    /// Campaign unlock order subset; first catalog level is always present.
    var unlockedLevelIDs: [String]
    /// Levels completed at least once (survives content-hash changes).
    var completedLevelIDs: [String]
    var lastSelectedLevelID: String?
    /// Tutorial hint IDs already shown via level intro.
    var seenTutorialHintIDs: [String]
    /// Best-score rows; multiple hashes per level ID may coexist.
    var records: [SokobanLevelRecordV1]

    static func fresh(firstLevelID: String) -> ProgressFileV1 {
        ProgressFileV1(
            schemaVersion: currentSchemaVersion,
            unlockedLevelIDs: [firstLevelID],
            completedLevelIDs: [],
            lastSelectedLevelID: firstLevelID,
            seenTutorialHintIDs: [],
            records: []
        )
    }

    /// No completions yet and only the starting level unlocked.
    var isFreshCampaign: Bool {
        completedLevelIDs.isEmpty && unlockedLevelIDs.count <= 1
    }

    func isUnlocked(_ levelID: String) -> Bool {
        unlockedLevelIDs.contains(levelID)
    }

    func isCompleted(_ levelID: String) -> Bool {
        completedLevelIDs.contains(levelID)
    }

    func hasSeenHint(_ hintID: String) -> Bool {
        seenTutorialHintIDs.contains(hintID)
    }

    func record(
        levelID: String,
        contentHash: String,
        ruleVersion: Int
    ) -> SokobanLevelRecordV1? {
        records.first {
            $0.levelID == levelID
                && $0.contentHash == contentHash
                && $0.ruleVersion == ruleVersion
        }
    }
}

/// Best scores for one level content fingerprint.
struct SokobanLevelRecordV1: Codable, Equatable, Sendable {
    let levelID: String
    let contentHash: String
    let ruleVersion: Int
    /// Independently tracked; either field may improve without the other.
    var bestMoveCount: Int?
    var bestPushCount: Int?
}

/// Result of applying a terminal completion to progress.
struct ProgressCompletionDelta: Equatable, Sendable {
    let newlyCompleted: Bool
    let unlockedLevelID: String?
    let newBestMoves: Bool
    let newBestPushes: Bool
    let bestMoveCount: Int?
    let bestPushCount: Int?

    var hasNewRecord: Bool { newBestMoves || newBestPushes }
}
