import Foundation
import GameCore

/// Versioned campaign progress (schema 1).
///
/// Unlock / “ever completed” keys use stable level IDs only. Best scores are
/// keyed by level ID + content hash + rule version so revised geometry does not
/// inherit old records or revoke unlocks.
///
/// Sokoban and Cave keep separate unlock / completion / record lists so a fresh
/// Sokoban campaign is independent of Cave progress (and vice versa). Cave
/// fields are optional in JSON for backward compatibility with older V1 files.
struct ProgressFileV1: Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    /// Sokoban unlock order subset; first catalog level is always present.
    var unlockedLevelIDs: [String]
    /// Sokoban levels completed at least once (survives content-hash changes).
    var completedLevelIDs: [String]
    var lastSelectedLevelID: String?
    /// Tutorial hint IDs already shown via level intro.
    var seenTutorialHintIDs: [String]
    /// Sokoban best-score rows; multiple hashes per level ID may coexist.
    var records: [SokobanLevelRecordV1]

    /// Cave tutorials are always present; campaign levels unlock on completion.
    var unlockedCaveLevelIDs: [String]
    var completedCaveLevelIDs: [String]
    var lastSelectedCaveLevelID: String?
    var caveRecords: [CaveLevelRecordV1]

    static func fresh(
        firstLevelID: String,
        caveTutorialLevelIDs: [String] = []
    ) -> ProgressFileV1 {
        ProgressFileV1(
            schemaVersion: currentSchemaVersion,
            unlockedLevelIDs: [firstLevelID],
            completedLevelIDs: [],
            lastSelectedLevelID: firstLevelID,
            seenTutorialHintIDs: [],
            records: [],
            unlockedCaveLevelIDs: caveTutorialLevelIDs,
            completedCaveLevelIDs: [],
            lastSelectedCaveLevelID: caveTutorialLevelIDs.first,
            caveRecords: []
        )
    }

    /// No Sokoban completions yet and only the starting level unlocked.
    var isFreshCampaign: Bool {
        completedLevelIDs.isEmpty && unlockedLevelIDs.count <= 1
    }

    /// No Cave completions yet and only tutorial caves unlocked.
    func isFreshCaveCampaign(tutorialLevelIDs: [String]) -> Bool {
        completedCaveLevelIDs.isEmpty
            && unlockedCaveLevelIDs.allSatisfy { tutorialLevelIDs.contains($0) }
    }

    func isUnlocked(_ levelID: String) -> Bool {
        unlockedLevelIDs.contains(levelID)
    }

    func isCompleted(_ levelID: String) -> Bool {
        completedLevelIDs.contains(levelID)
    }

    func isCaveUnlocked(_ levelID: String) -> Bool {
        unlockedCaveLevelIDs.contains(levelID)
    }

    func isCaveCompleted(_ levelID: String) -> Bool {
        completedCaveLevelIDs.contains(levelID)
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

    func caveRecord(
        levelID: String,
        contentHash: String,
        ruleVersion: Int
    ) -> CaveLevelRecordV1? {
        caveRecords.first {
            $0.levelID == levelID
                && $0.contentHash == contentHash
                && $0.ruleVersion == ruleVersion
        }
    }
}

extension ProgressFileV1: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case unlockedLevelIDs
        case completedLevelIDs
        case lastSelectedLevelID
        case seenTutorialHintIDs
        case records
        case unlockedCaveLevelIDs
        case completedCaveLevelIDs
        case lastSelectedCaveLevelID
        case caveRecords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        unlockedLevelIDs = try container.decode([String].self, forKey: .unlockedLevelIDs)
        completedLevelIDs = try container.decode([String].self, forKey: .completedLevelIDs)
        lastSelectedLevelID = try container.decodeIfPresent(String.self, forKey: .lastSelectedLevelID)
        seenTutorialHintIDs = try container.decodeIfPresent([String].self, forKey: .seenTutorialHintIDs) ?? []
        records = try container.decodeIfPresent([SokobanLevelRecordV1].self, forKey: .records) ?? []
        unlockedCaveLevelIDs =
            try container.decodeIfPresent([String].self, forKey: .unlockedCaveLevelIDs) ?? []
        completedCaveLevelIDs =
            try container.decodeIfPresent([String].self, forKey: .completedCaveLevelIDs) ?? []
        lastSelectedCaveLevelID =
            try container.decodeIfPresent(String.self, forKey: .lastSelectedCaveLevelID)
        caveRecords = try container.decodeIfPresent([CaveLevelRecordV1].self, forKey: .caveRecords) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(unlockedLevelIDs, forKey: .unlockedLevelIDs)
        try container.encode(completedLevelIDs, forKey: .completedLevelIDs)
        try container.encodeIfPresent(lastSelectedLevelID, forKey: .lastSelectedLevelID)
        try container.encode(seenTutorialHintIDs, forKey: .seenTutorialHintIDs)
        try container.encode(records, forKey: .records)
        try container.encode(unlockedCaveLevelIDs, forKey: .unlockedCaveLevelIDs)
        try container.encode(completedCaveLevelIDs, forKey: .completedCaveLevelIDs)
        try container.encodeIfPresent(lastSelectedCaveLevelID, forKey: .lastSelectedCaveLevelID)
        try container.encode(caveRecords, forKey: .caveRecords)
    }
}

/// Best scores for one Sokoban level content fingerprint.
struct SokobanLevelRecordV1: Codable, Equatable, Sendable {
    let levelID: String
    let contentHash: String
    let ruleVersion: Int
    /// Independently tracked; either field may improve without the other.
    var bestMoveCount: Int?
    var bestPushCount: Int?
}

/// Best scores for one Cave level content fingerprint (higher is better).
struct CaveLevelRecordV1: Codable, Equatable, Sendable {
    let levelID: String
    let contentHash: String
    let ruleVersion: Int
    var bestScore: Int?
    var bestRemainingTicks: Int?
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

/// Result of applying a terminal Cave completion to progress.
struct CaveProgressCompletionDelta: Equatable, Sendable {
    let newlyCompleted: Bool
    let unlockedLevelID: String?
    let newBestScore: Bool
    let newBestRemainingTicks: Bool
    let bestScore: Int?
    let bestRemainingTicks: Int?

    var hasNewRecord: Bool { newBestScore || newBestRemainingTicks }
}
