import Foundation

/// Owns load/backup paths and the global write generation for Sokoban runs.
@MainActor
final class SokobanRunPersistence: SokobanRunSaveSink {
    /// `nil` when persistence is disabled (no usable Application Support folder).
    let configuration: SokobanRunStoreConfiguration?
    /// Why writes are disabled; `nil` when active.
    let disabledReason: String?

    private let fileManager: FileManager
    private let writer: SokobanRunWriter?

    private var writeGeneration: UInt64 = 0
    /// Last DTO handed to ``scheduleSave`` — used for synchronous termination writes.
    private var latestCachedFile: SokobanRunFileV1?

    /// Non-blocking save failures for the controller to surface.
    var onSaveFailure: ((String) -> Void)?

    var isEnabled: Bool { disabledReason == nil }

    private init(
        configuration: SokobanRunStoreConfiguration?,
        disabledReason: String?,
        fileManager: FileManager
    ) {
        self.configuration = configuration
        self.disabledReason = disabledReason
        self.fileManager = fileManager
        if let configuration, disabledReason == nil {
            self.writer = SokobanRunWriter(fileURL: configuration.fileURL)
        } else {
            self.writer = nil
        }
    }

    convenience init(
        configuration: SokobanRunStoreConfiguration,
        fileManager: FileManager = .default
    ) {
        self.init(configuration: configuration, disabledReason: nil, fileManager: fileManager)
    }

    static func production() throws -> SokobanRunPersistence {
        try SokobanRunPersistence(configuration: .applicationSupport())
    }

    static func ephemeral() throws -> SokobanRunPersistence {
        try SokobanRunPersistence(configuration: .ephemeral())
    }

    /// Production store, or a no-op store with a visible reason when setup fails.
    static func makeDefault() -> SokobanRunPersistence {
        do {
            return try production()
        } catch {
            return disabled(reason: "Could not open the save folder: \(error.localizedDescription)")
        }
    }

    static func disabled(reason: String) -> SokobanRunPersistence {
        SokobanRunPersistence(
            configuration: nil,
            disabledReason: reason,
            fileManager: .default
        )
    }

    func scheduleSave(_ file: SokobanRunFileV1) {
        latestCachedFile = file
        guard let writer else { return }

        writeGeneration &+= 1
        let generation = writeGeneration
        Task {
            await writer.enqueue(generation: generation, file: file)
        }
    }

    func flush() async {
        guard let writer else { return }

        // The fire-and-forget Task from ``scheduleSave`` may not have reached the
        // actor yet while an older generation is still writing. Enqueue the cached
        // DTO here so flush waits for generation N after any in-flight N−1 write.
        if let file = latestCachedFile, writeGeneration > 0 {
            await writer.enqueue(generation: writeGeneration, file: file)
        }

        await writer.flush()
        if let message = await writer.lastError {
            onSaveFailure?(message)
        }
    }

    /// Synchronously persists the latest cached DTO without hopping through Tasks.
    ///
    /// Safe to call only after the writer is idle (for example after ``flush()``),
    /// or as a best-effort path when no older write can still be in flight.
    func writeCachedRunSynchronously() {
        guard isEnabled else { return }
        guard let file = latestCachedFile else { return }
        guard let url = configuration?.fileURL else { return }
        do {
            try SokobanRunWriter.atomicWrite(file: file, to: url)
        } catch {
            onSaveFailure?("Could not save progress: \(error)")
        }
    }

    func load() -> SokobanRunLoadOutcome {
        guard let configuration else {
            return .absent
        }

        let url = configuration.fileURL
        guard fileManager.fileExists(atPath: url.path) else {
            return .absent
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return .readFailed(message: "Could not read run file: \(error.localizedDescription)")
        }

        // Peek schema before full decode.
        // Newer schemas must stay in place; older / unknown lower versions are quarantined.
        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let schemaVersion = root["schemaVersion"] as? Int
        {
            if schemaVersion > SokobanRunFileV1.currentSchemaVersion {
                return .invalid(
                    message: "Run file schema version \(schemaVersion) is not supported.",
                    preservedOriginal: true
                )
            }
            if schemaVersion < SokobanRunFileV1.currentSchemaVersion {
                let backedUp = backupInvalidFile(preservingOriginalData: data)
                return .invalid(
                    message: "Run file schema version \(schemaVersion) is outdated.",
                    preservedOriginal: backedUp
                )
            }
        }

        let file: SokobanRunFileV1
        do {
            file = try SokobanRunFileCodec.decode(data)
        } catch SokobanRunCodecError.fileTooLarge(let count) {
            let backedUp = backupInvalidFile(preservingOriginalData: data)
            return .invalid(
                message: "Run file is too large (\(count) bytes).",
                preservedOriginal: backedUp
            )
        } catch {
            let backedUp = backupInvalidFile(preservingOriginalData: data)
            return .invalid(
                message: "Run file is damaged or not valid JSON.",
                preservedOriginal: backedUp
            )
        }

        return .loaded(file)
    }

    /// Removes the active run file after the player chooses a fresh start.
    func removeRunFile() {
        guard let url = configuration?.fileURL else { return }
        try? fileManager.removeItem(at: url)
        latestCachedFile = nil
    }

    /// Copies the current file aside as `.invalid-<timestamp>.json`.
    @discardableResult
    func backupInvalidFile(preservingOriginalData data: Data? = nil) -> Bool {
        guard let configuration else { return false }
        let url = configuration.fileURL
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupName = "sokoban-run-v1.invalid-\(stamp).json"
        let backupURL = configuration.directoryURL.appendingPathComponent(backupName)

        do {
            if let data {
                try data.write(to: backupURL, options: .atomic)
                try? fileManager.removeItem(at: url)
            } else if fileManager.fileExists(atPath: url.path) {
                try fileManager.copyItem(at: url, to: backupURL)
                try fileManager.removeItem(at: url)
            } else {
                return false
            }
            return true
        } catch {
            return false
        }
    }

    /// After restore validation fails on an already-decoded V1 file.
    func quarantineLoadedInvalidFile(message: String) -> SokobanRunLoadOutcome {
        let preserved = backupInvalidFile()
        return .invalid(message: message, preservedOriginal: preserved)
    }
}
