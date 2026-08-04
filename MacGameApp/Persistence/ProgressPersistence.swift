import Foundation

/// Owns load/save for ``ProgressFileV1`` with atomic writes.
@MainActor
final class ProgressPersistence {
    struct Configuration: Sendable {
        let directoryURL: URL
        let fileName: String

        static let defaultFileName = "progress-v1.json"

        var fileURL: URL {
            directoryURL.appendingPathComponent(fileName, isDirectory: false)
        }

        static func applicationSupport(
            fileManager: FileManager = .default,
            fileName: String = defaultFileName
        ) throws -> Configuration {
            let base = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = base.appendingPathComponent("SokoBoulder", isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return Configuration(directoryURL: directory, fileName: fileName)
        }

        static func ephemeral(
            fileManager: FileManager = .default,
            fileName: String = defaultFileName
        ) throws -> Configuration {
            let directory = fileManager.temporaryDirectory
                .appendingPathComponent(
                    "SokoBoulder-progress-\(UUID().uuidString)",
                    isDirectory: true
                )
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return Configuration(directoryURL: directory, fileName: fileName)
        }
    }

    private let configuration: Configuration?
    private let fileManager: FileManager
    /// When false, in-memory progress still drives UI but disk is never touched.
    private let allowsWrites: Bool
    private let caveTutorialLevelIDs: [String]

    /// In-memory progress; always valid for gameplay decisions.
    private(set) var file: ProgressFileV1

    /// Why the store cannot be used for durable progress; `nil` when writable.
    let disabledReason: String?
    /// Non-blocking diagnostic produced while loading existing progress.
    let loadDiagnostic: String?

    /// Non-blocking save failures for the controller to surface.
    var onSaveFailure: ((String) -> Void)?

    var isEnabled: Bool { disabledReason == nil && allowsWrites }

    private init(
        configuration: Configuration?,
        disabledReason: String?,
        loadDiagnostic: String?,
        allowsWrites: Bool,
        fileManager: FileManager,
        caveTutorialLevelIDs: [String],
        initial: ProgressFileV1
    ) {
        self.configuration = configuration
        self.disabledReason = disabledReason
        self.loadDiagnostic = loadDiagnostic
        self.allowsWrites = allowsWrites
        self.fileManager = fileManager
        self.caveTutorialLevelIDs = caveTutorialLevelIDs
        self.file = initial
    }

    /// Loads from disk or starts a fresh campaign file.
    convenience init(
        configuration: Configuration,
        firstLevelID: String,
        caveTutorialLevelIDs: [String] = [],
        fileManager: FileManager = .default
    ) {
        let loaded = Self.loadFile(
            configuration: configuration,
            firstLevelID: firstLevelID,
            caveTutorialLevelIDs: caveTutorialLevelIDs,
            fileManager: fileManager
        )
        self.init(
            configuration: configuration,
            disabledReason: loaded.disabledReason,
            loadDiagnostic: loaded.diagnostic,
            allowsWrites: loaded.allowsWrites,
            fileManager: fileManager,
            caveTutorialLevelIDs: caveTutorialLevelIDs,
            initial: loaded.file
        )
        if loaded.shouldPersistSeed {
            persist()
        }
    }

    static func production(
        firstLevelID: String,
        caveTutorialLevelIDs: [String] = []
    ) throws -> ProgressPersistence {
        try ProgressPersistence(
            configuration: .applicationSupport(),
            firstLevelID: firstLevelID,
            caveTutorialLevelIDs: caveTutorialLevelIDs
        )
    }

    static func ephemeral(
        firstLevelID: String,
        caveTutorialLevelIDs: [String] = []
    ) throws -> ProgressPersistence {
        try ProgressPersistence(
            configuration: .ephemeral(),
            firstLevelID: firstLevelID,
            caveTutorialLevelIDs: caveTutorialLevelIDs
        )
    }

    /// Shares a directory with run-file tests.
    static func ephemeral(
        directoryURL: URL,
        firstLevelID: String,
        caveTutorialLevelIDs: [String] = []
    ) throws -> ProgressPersistence {
        try ProgressPersistence(
            configuration: Configuration(
                directoryURL: directoryURL,
                fileName: Configuration.defaultFileName
            ),
            firstLevelID: firstLevelID,
            caveTutorialLevelIDs: caveTutorialLevelIDs
        )
    }

    static func makeDefault(
        firstLevelID: String,
        caveTutorialLevelIDs: [String] = []
    ) -> ProgressPersistence {
        do {
            return try production(
                firstLevelID: firstLevelID,
                caveTutorialLevelIDs: caveTutorialLevelIDs
            )
        } catch {
            return disabled(
                reason: "Could not open the progress folder: \(error.localizedDescription)",
                firstLevelID: firstLevelID,
                caveTutorialLevelIDs: caveTutorialLevelIDs
            )
        }
    }

    static func disabled(
        reason: String,
        firstLevelID: String,
        caveTutorialLevelIDs: [String] = []
    ) -> ProgressPersistence {
        ProgressPersistence(
            configuration: nil,
            disabledReason: reason,
            loadDiagnostic: nil,
            allowsWrites: false,
            fileManager: .default,
            caveTutorialLevelIDs: caveTutorialLevelIDs,
            initial: .fresh(
                firstLevelID: firstLevelID,
                caveTutorialLevelIDs: caveTutorialLevelIDs
            )
        )
    }

    /// Disabled placeholder for the content-fault UI; contains no synthetic level identity.
    static func unavailable(reason: String) -> ProgressPersistence {
        ProgressPersistence(
            configuration: nil,
            disabledReason: reason,
            loadDiagnostic: nil,
            allowsWrites: false,
            fileManager: .default,
            caveTutorialLevelIDs: [],
            initial: ProgressFileV1(
                schemaVersion: ProgressFileV1.currentSchemaVersion,
                unlockedLevelIDs: [],
                completedLevelIDs: [],
                lastSelectedLevelID: nil,
                seenTutorialHintIDs: [],
                records: [],
                unlockedCaveLevelIDs: [],
                completedCaveLevelIDs: [],
                lastSelectedCaveLevelID: nil,
                caveRecords: []
            )
        )
    }

    // MARK: - Mutations

    @discardableResult
    func recordCompletion(
        levelID: String,
        contentHash: String,
        ruleVersion: Int,
        moveCount: Int,
        pushCount: Int,
        nextLevelID: String?
    ) -> ProgressCompletionDelta {
        var next = file
        let newlyCompleted = !next.completedLevelIDs.contains(levelID)
        if newlyCompleted {
            next.completedLevelIDs.append(levelID)
        }

        var unlockedLevelID: String?
        if let nextLevelID, !next.unlockedLevelIDs.contains(nextLevelID) {
            next.unlockedLevelIDs.append(nextLevelID)
            unlockedLevelID = nextLevelID
        }

        if !next.unlockedLevelIDs.contains(levelID) {
            next.unlockedLevelIDs.append(levelID)
        }

        next.lastSelectedLevelID = levelID

        let existingIndex = next.records.firstIndex {
            $0.levelID == levelID
                && $0.contentHash == contentHash
                && $0.ruleVersion == ruleVersion
        }
        var record = existingIndex.map { next.records[$0] }
            ?? SokobanLevelRecordV1(
                levelID: levelID,
                contentHash: contentHash,
                ruleVersion: ruleVersion,
                bestMoveCount: nil,
                bestPushCount: nil
            )

        var newBestMoves = false
        var newBestPushes = false
        if record.bestMoveCount.map({ moveCount < $0 }) ?? true {
            record.bestMoveCount = moveCount
            newBestMoves = true
        }
        if record.bestPushCount.map({ pushCount < $0 }) ?? true {
            record.bestPushCount = pushCount
            newBestPushes = true
        }

        if let existingIndex {
            next.records[existingIndex] = record
        } else {
            next.records.append(record)
        }

        file = next
        persist()
        return ProgressCompletionDelta(
            newlyCompleted: newlyCompleted,
            unlockedLevelID: unlockedLevelID,
            newBestMoves: newBestMoves,
            newBestPushes: newBestPushes,
            bestMoveCount: record.bestMoveCount,
            bestPushCount: record.bestPushCount
        )
    }

    @discardableResult
    func recordCaveCompletion(
        levelID: String,
        contentHash: String,
        ruleVersion: Int,
        score: Int,
        remainingTicks: Int,
        nextLevelID: String?
    ) -> CaveProgressCompletionDelta {
        var next = file
        let newlyCompleted = !next.completedCaveLevelIDs.contains(levelID)
        if newlyCompleted {
            next.completedCaveLevelIDs.append(levelID)
        }

        var unlockedLevelID: String?
        if let nextLevelID, !next.unlockedCaveLevelIDs.contains(nextLevelID) {
            next.unlockedCaveLevelIDs.append(nextLevelID)
            unlockedLevelID = nextLevelID
        }

        if !next.unlockedCaveLevelIDs.contains(levelID) {
            next.unlockedCaveLevelIDs.append(levelID)
        }

        next.lastSelectedCaveLevelID = levelID

        let existingIndex = next.caveRecords.firstIndex {
            $0.levelID == levelID
                && $0.contentHash == contentHash
                && $0.ruleVersion == ruleVersion
        }
        var record = existingIndex.map { next.caveRecords[$0] }
            ?? CaveLevelRecordV1(
                levelID: levelID,
                contentHash: contentHash,
                ruleVersion: ruleVersion,
                bestScore: nil,
                bestRemainingTicks: nil
            )

        var newBestScore = false
        var newBestRemainingTicks = false
        if record.bestScore.map({ score > $0 }) ?? true {
            record.bestScore = score
            newBestScore = true
        }
        if record.bestRemainingTicks.map({ remainingTicks > $0 }) ?? true {
            record.bestRemainingTicks = remainingTicks
            newBestRemainingTicks = true
        }

        if let existingIndex {
            next.caveRecords[existingIndex] = record
        } else {
            next.caveRecords.append(record)
        }

        file = next
        persist()
        return CaveProgressCompletionDelta(
            newlyCompleted: newlyCompleted,
            unlockedLevelID: unlockedLevelID,
            newBestScore: newBestScore,
            newBestRemainingTicks: newBestRemainingTicks,
            bestScore: record.bestScore,
            bestRemainingTicks: record.bestRemainingTicks
        )
    }

    func markHintSeen(_ hintID: String) {
        guard !hintID.isEmpty, !file.seenTutorialHintIDs.contains(hintID) else { return }
        file.seenTutorialHintIDs.append(hintID)
        persist()
    }

    func selectLevel(_ levelID: String) {
        guard file.lastSelectedLevelID != levelID else { return }
        file.lastSelectedLevelID = levelID
        persist()
    }

    func selectCaveLevel(_ levelID: String) {
        guard file.lastSelectedCaveLevelID != levelID else { return }
        file.lastSelectedCaveLevelID = levelID
        persist()
    }

    /// Clears Sokoban unlocks, completions, records, and seen hints; Cave progress is kept.
    func resetToFresh(firstLevelID: String) {
        file.unlockedLevelIDs = [firstLevelID]
        file.completedLevelIDs = []
        file.lastSelectedLevelID = firstLevelID
        file.seenTutorialHintIDs = []
        file.records = []
        persist()
    }

    /// Clears Cave unlocks/completions/records back to always-free tutorials.
    func resetCaveToFresh(tutorialLevelIDs: [String]? = nil) {
        let tutorials = tutorialLevelIDs ?? caveTutorialLevelIDs
        file.unlockedCaveLevelIDs = tutorials
        file.completedCaveLevelIDs = []
        file.lastSelectedCaveLevelID = tutorials.first
        file.caveRecords = []
        persist()
    }

    /// Cheat: unlock every level ID in `ids` for the Sokoban campaign.
    func unlockAllLevels(_ ids: [String]) {
        var changed = false
        for id in ids where !file.unlockedLevelIDs.contains(id) {
            file.unlockedLevelIDs.append(id)
            changed = true
        }
        if changed { persist() }
    }

    /// Cheat: unlock every level ID in `ids` for the Cave campaign.
    func unlockAllCaveLevels(_ ids: [String]) {
        var changed = false
        for id in ids where !file.unlockedCaveLevelIDs.contains(id) {
            file.unlockedCaveLevelIDs.append(id)
            changed = true
        }
        if changed { persist() }
    }

    var isFreshCaveCampaign: Bool {
        file.isFreshCaveCampaign(tutorialLevelIDs: caveTutorialLevelIDs)
    }

    func availability(
        for levelID: String,
        in catalog: SokobanContentCatalog
    ) -> LevelAvailability {
        guard catalog.descriptor(id: levelID) != nil else { return .locked }
        if !file.isUnlocked(levelID) { return .locked }
        if file.isCompleted(levelID) { return .completed }
        return .available
    }

    func caveAvailability(
        for levelID: String,
        in catalog: CaveContentCatalog
    ) -> LevelAvailability {
        guard catalog.descriptor(id: levelID) != nil else { return .locked }
        if !file.isCaveUnlocked(levelID) { return .locked }
        if file.isCaveCompleted(levelID) { return .completed }
        return .available
    }

    // MARK: - Private

    private struct LoadResult {
        let file: ProgressFileV1
        let diagnostic: String?
        let disabledReason: String?
        let allowsWrites: Bool
        let shouldPersistSeed: Bool
    }

    private static func loadFile(
        configuration: Configuration,
        firstLevelID: String,
        caveTutorialLevelIDs: [String],
        fileManager: FileManager
    ) -> LoadResult {
        let url = configuration.fileURL
        guard fileManager.fileExists(atPath: url.path) else {
            return LoadResult(
                file: .fresh(
                    firstLevelID: firstLevelID,
                    caveTutorialLevelIDs: caveTutorialLevelIDs
                ),
                diagnostic: nil,
                disabledReason: nil,
                allowsWrites: true,
                shouldPersistSeed: false
            )
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return LoadResult(
                file: .fresh(
                    firstLevelID: firstLevelID,
                    caveTutorialLevelIDs: caveTutorialLevelIDs
                ),
                diagnostic: "Could not read progress: \(error.localizedDescription)",
                disabledReason: nil,
                allowsWrites: true,
                shouldPersistSeed: false
            )
        }

        guard let schemaVersion = ProgressFileCodec.peekSchemaVersion(data) else {
            return quarantineCorrupt(
                url: url,
                firstLevelID: firstLevelID,
                caveTutorialLevelIDs: caveTutorialLevelIDs,
                fileManager: fileManager
            )
        }

        if schemaVersion > ProgressFileV1.currentSchemaVersion {
            // Preserve the original file; play with an ephemeral in-memory campaign.
            return LoadResult(
                file: .fresh(
                    firstLevelID: firstLevelID,
                    caveTutorialLevelIDs: caveTutorialLevelIDs
                ),
                diagnostic:
                    "Progress schema \(schemaVersion) is newer than this build; progress will not be saved.",
                disabledReason:
                    "Progress file version \(schemaVersion) is not supported; writes are disabled.",
                allowsWrites: false,
                shouldPersistSeed: false
            )
        }

        if schemaVersion < ProgressFileV1.currentSchemaVersion {
            // No migrations yet — treat as unusable for this build.
            return quarantineCorrupt(
                url: url,
                firstLevelID: firstLevelID,
                caveTutorialLevelIDs: caveTutorialLevelIDs,
                fileManager: fileManager
            )
        }

        do {
            var file = try ProgressFileCodec.decode(data)
            var seeded = false
            if !file.unlockedLevelIDs.contains(firstLevelID) {
                file.unlockedLevelIDs.insert(firstLevelID, at: 0)
                seeded = true
            }
            for id in caveTutorialLevelIDs where !file.unlockedCaveLevelIDs.contains(id) {
                file.unlockedCaveLevelIDs.append(id)
                seeded = true
            }
            if file.lastSelectedCaveLevelID == nil {
                file.lastSelectedCaveLevelID = caveTutorialLevelIDs.first
            }
            return LoadResult(
                file: file,
                diagnostic: nil,
                disabledReason: nil,
                allowsWrites: true,
                shouldPersistSeed: seeded
            )
        } catch {
            return quarantineCorrupt(
                url: url,
                firstLevelID: firstLevelID,
                caveTutorialLevelIDs: caveTutorialLevelIDs,
                fileManager: fileManager
            )
        }
    }

    private static func quarantineCorrupt(
        url: URL,
        firstLevelID: String,
        caveTutorialLevelIDs: [String],
        fileManager: FileManager
    ) -> LoadResult {
        let backup = url.deletingLastPathComponent()
            .appendingPathComponent(
                "progress-v1.invalid-\(Int(Date().timeIntervalSince1970)).json"
            )
        try? fileManager.moveItem(at: url, to: backup)
        return LoadResult(
            file: .fresh(
                firstLevelID: firstLevelID,
                caveTutorialLevelIDs: caveTutorialLevelIDs
            ),
            diagnostic: "Progress file was invalid and was set aside.",
            disabledReason: nil,
            allowsWrites: true,
            shouldPersistSeed: false
        )
    }

    private func persist() {
        guard allowsWrites, disabledReason == nil, let configuration else { return }
        do {
            try ProgressFileCodec.atomicWrite(file, to: configuration.fileURL)
        } catch {
            onSaveFailure?("Could not save progress: \(error)")
        }
    }
}

enum LevelAvailability: Equatable, Sendable {
    case locked
    case available
    case completed
}
