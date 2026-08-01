import Foundation

/// Serializes run-file writes with monotonic generations and coalescing.
///
/// `enqueue` only updates the pending job and ensures a single drain worker is
/// running. The worker yields before each write and performs I/O off the actor so
/// newer mutations can replace `pending` while a write is in flight.
actor SokobanRunWriter {
    private let fileURL: URL

    private var pending: (generation: UInt64, file: SokobanRunFileV1)?
    private var lastCommittedGeneration: UInt64 = 0
    private var drainTask: Task<Void, Never>?
    private var lastErrorMessage: String?

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    var lastError: String? { lastErrorMessage }

    /// Records a write job without waiting for disk I/O.
    func enqueue(generation: UInt64, file: SokobanRunFileV1) {
        if let pending, pending.generation > generation {
            return
        }
        pending = (generation, file)
        ensureDrainRunning()
    }

    /// Waits until every coalesced job has finished (or failed).
    func flush() async {
        ensureDrainRunning()
        while drainTask != nil || pending != nil {
            if let drainTask {
                await drainTask.value
            } else if pending != nil {
                ensureDrainRunning()
            } else {
                break
            }
        }
    }

    /// Test helper: committed generation after successful writes.
    func committedGeneration() -> UInt64 {
        lastCommittedGeneration
    }

    private func ensureDrainRunning() {
        guard drainTask == nil else { return }
        drainTask = Task { await self.drainLoop() }
    }

    private func drainLoop() async {
        defer {
            drainTask = nil
            // An enqueue may have raced with our empty-pending exit.
            if pending != nil {
                ensureDrainRunning()
            }
        }

        while true {
            // Let concurrent enqueue calls replace `pending` before we snapshot.
            await Task.yield()

            guard let job = pending else { return }
            guard job.generation > lastCommittedGeneration else {
                if pending?.generation == job.generation {
                    pending = nil
                }
                continue
            }

            pending = nil
            let url = fileURL
            let outcome = await Task.detached(priority: .utility) {
                Result { try SokobanRunWriter.atomicWrite(file: job.file, to: url) }
            }.value

            switch outcome {
            case .success:
                lastCommittedGeneration = job.generation
                lastErrorMessage = nil
            case .failure(let error):
                lastErrorMessage = String(describing: error)
            }
        }
    }

    static func atomicWrite(
        file: SokobanRunFileV1,
        to fileURL: URL
    ) throws {
        let fileManager = FileManager.default
        let data: Data
        do {
            data = try SokobanRunFileCodec.encode(file)
        } catch {
            throw SokobanRunWriteError.encodingFailed
        }

        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let temporaryURL = directory.appendingPathComponent(
            ".\(fileURL.lastPathComponent).tmp-\(UUID().uuidString)"
        )
        do {
            try data.write(to: temporaryURL, options: .atomic)
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try fileManager.replaceItemAt(fileURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: fileURL)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw SokobanRunWriteError.ioFailed(String(describing: error))
        }
    }
}
