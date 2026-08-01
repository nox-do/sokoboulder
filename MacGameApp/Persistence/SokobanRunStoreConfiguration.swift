import Foundation

/// Injectable locations for the Sokoban run file.
struct SokobanRunStoreConfiguration: Sendable {
    let directoryURL: URL
    let fileName: String

    static let defaultFileName = "sokoban-run-v1.json"

    var fileURL: URL {
        directoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    /// Production path: Application Support/SokoBoulder/.
    static func applicationSupport(
        fileManager: FileManager = .default,
        fileName: String = defaultFileName
    ) throws -> SokobanRunStoreConfiguration {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("SokoBoulder", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return SokobanRunStoreConfiguration(directoryURL: directory, fileName: fileName)
    }

    /// Unique temporary directory for tests.
    static func ephemeral(
        fileManager: FileManager = .default,
        fileName: String = defaultFileName
    ) throws -> SokobanRunStoreConfiguration {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("SokoBoulder-tests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return SokobanRunStoreConfiguration(directoryURL: directory, fileName: fileName)
    }
}

enum SokobanRunLoadOutcome: Equatable, Sendable {
    /// No run file present — normal first launch.
    case absent
    case loaded(SokobanRunFileV1)
    /// File exists but cannot be used. Original may have been preserved or backed up.
    case invalid(message: String, preservedOriginal: Bool)
    /// I/O failure while reading; original must not be moved.
    case readFailed(message: String)
}

enum SokobanRunWriteError: Error, Equatable, Sendable {
    case encodingFailed
    case ioFailed(String)
}
