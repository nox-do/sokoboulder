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
        initial: ProgressFileV1
    ) {
        self.configuration = configuration
        self.disabledReason = disabledReason
        self.loadDiagnostic = loadDiagnostic
        self.allowsWrites = allowsWrites
        self.fileManager = fileManager
        self.file = initial
    }

    /// Loads from disk or starts a fresh campaign file.
    convenience init(
        configuration: Configuration,
        firstLevelID: String,
        fileManager: FileManager = .default
    ) {
        let loaded = Self.loadFile(
            configuration: configuration,
            firstLevelID: firstLevelID,
            fileManager: fileManager
        )
        self.init(
            configuration: configuration,
            disabledReason: loaded.disabledReason,
            loadDiagnostic: loaded.diagnostic,
            allowsWrites: loaded.allowsWrites,
            fileManager: fileManager,
            initial: loaded.file
        )
    }

    static func production(firstLevelID: String) throws -> ProgressPersistence {
        try ProgressPersistence(
            configuration: .applicationSupport(),
            firstLevelID: firstLevelID
        )
    }

    static func ephemeral(firstLevelID: String) throws -> ProgressPersistence {
        try ProgressPersistence(
            configuration: .ephemeral(),
            firstLevelID: firstLevelID
        )
    }

    /// Shares a directory with run-file tests.
    static func ephemeral(
        directoryURL: URL,
        firstLevelID: String
    ) throws -> ProgressPersistence {
        try ProgressPersistence(
            configuration: Configuration(
                directoryURL: directoryURL,
                fileName: Configuration.defaultFileName
            ),
            firstLevelID: firstLevelID
        )
    }

    static func makeDefault(firstLevelID: String) -> ProgressPersistence {
        do {
            return try production(firstLevelID: firstLevelID)
        } catch {
            return disabled(
                reason: "Could not open the progress folder: \(error.localizedDescription)",
                firstLevelID: firstLevelID
            )
        }
    }

    static func disabled(reason: String, firstLevelID: String) -> ProgressPersistence {
        ProgressPersistence(
            configuration: nil,
            disabledReason: reason,
            loadDiagnostic: nil,
            allowsWrites: false,
            fileManager: .default,
            initial: .fresh(firstLevelID: firstLevelID)
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
            initial: ProgressFileV1(
                schemaVersion: ProgressFileV1.currentSchemaVersion,
                unlockedLevelIDs: [],
                completedLevelIDs: [],
                lastSelectedLevelID: nil,
                seenTutorialHintIDs: [],
                records: []
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

    func availability(
        for levelID: String,
        in catalog: SokobanContentCatalog
    ) -> LevelAvailability {
        guard catalog.descriptor(id: levelID) != nil else { return .locked }
        if !file.isUnlocked(levelID) { return .locked }
        if file.isCompleted(levelID) { return .completed }
        return .available
    }

    // MARK: - Private

    private struct LoadResult {
        let file: ProgressFileV1
        let diagnostic: String?
        let disabledReason: String?
        let allowsWrites: Bool
    }

    private static func loadFile(
        configuration: Configuration,
        firstLevelID: String,
        fileManager: FileManager
    ) -> LoadResult {
        let url = configuration.fileURL
        guard fileManager.fileExists(atPath: url.path) else {
            return LoadResult(
                file: .fresh(firstLevelID: firstLevelID),
                diagnostic: nil,
                disabledReason: nil,
                allowsWrites: true
            )
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return LoadResult(
                file: .fresh(firstLevelID: firstLevelID),
                diagnostic: "Could not read progress: \(error.localizedDescription)",
                disabledReason: nil,
                allowsWrites: true
            )
        }

        guard let schemaVersion = ProgressFileCodec.peekSchemaVersion(data) else {
            return quarantineCorrupt(
                url: url,
                firstLevelID: firstLevelID,
                fileManager: fileManager
            )
        }

        if schemaVersion > ProgressFileV1.currentSchemaVersion {
            // Preserve the original file; play with an ephemeral in-memory campaign.
            return LoadResult(
                file: .fresh(firstLevelID: firstLevelID),
                diagnostic:
                    "Progress schema \(schemaVersion) is newer than this build; progress will not be saved.",
                disabledReason:
                    "Progress file version \(schemaVersion) is not supported; writes are disabled.",
                allowsWrites: false
            )
        }

        if schemaVersion < ProgressFileV1.currentSchemaVersion {
            // No migrations yet — treat as unusable for this build.
            return quarantineCorrupt(
                url: url,
                firstLevelID: firstLevelID,
                fileManager: fileManager
            )
        }

        do {
            var file = try ProgressFileCodec.decode(data)
            if !file.unlockedLevelIDs.contains(firstLevelID) {
                file.unlockedLevelIDs.insert(firstLevelID, at: 0)
            }
            return LoadResult(
                file: file,
                diagnostic: nil,
                disabledReason: nil,
                allowsWrites: true
            )
        } catch {
            return quarantineCorrupt(
                url: url,
                firstLevelID: firstLevelID,
                fileManager: fileManager
            )
        }
    }

    private static func quarantineCorrupt(
        url: URL,
        firstLevelID: String,
        fileManager: FileManager
    ) -> LoadResult {
        let backup = url.deletingLastPathComponent()
            .appendingPathComponent(
                "progress-v1.invalid-\(Int(Date().timeIntervalSince1970)).json"
            )
        try? fileManager.moveItem(at: url, to: backup)
        return LoadResult(
            file: .fresh(firstLevelID: firstLevelID),
            diagnostic: "Progress file was invalid and was set aside.",
            disabledReason: nil,
            allowsWrites: true
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
