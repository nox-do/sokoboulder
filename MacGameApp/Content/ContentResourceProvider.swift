import Foundation

/// Reads content bytes by stable relative path (no basename fallback).
protocol ContentResourceProvider: Sendable {
    /// Returns file contents for a path relative to the content root.
    ///
    /// Paths use `/` separators and must resolve inside the provider root.
    func data(at path: String) throws -> Data

    /// Returns a file URL for a path relative to the content root.
    func url(at path: String) throws -> URL
}

/// Bundle-backed provider. Paths are relative to ``Bundle/resourceURL``.
struct BundleContentResources: ContentResourceProvider {
    let bundle: Bundle

    init(bundle: Bundle) {
        self.bundle = bundle
    }

    func data(at path: String) throws -> Data {
        let url = try url(at: path)
        do {
            return try Data(contentsOf: url)
        } catch {
            throw ContentLoadError.unreadable(path: path, detail: String(describing: error))
        }
    }

    func url(at path: String) throws -> URL {
        guard let root = bundle.resourceURL else {
            throw ContentLoadError.missingResource(path: path)
        }
        return try ContentPath.resolve(path, under: root)
    }
}

/// Directory-backed provider for tests and tooling.
struct DirectoryContentResources: ContentResourceProvider {
    let root: URL

    init(root: URL) {
        self.root = root
    }

    func data(at path: String) throws -> Data {
        let url = try url(at: path)
        do {
            return try Data(contentsOf: url)
        } catch {
            throw ContentLoadError.unreadable(path: path, detail: String(describing: error))
        }
    }

    func url(at path: String) throws -> URL {
        try ContentPath.resolve(path, under: root)
    }
}

enum ContentPath {
    /// Resolves `path` under `root`, rejecting empty paths and `..` traversal.
    static func resolve(_ path: String, under root: URL) throws -> URL {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else {
            throw ContentLoadError.missingResource(path: path)
        }
        let parts = trimmed.split(separator: "/").map(String.init)
        guard parts.allSatisfy({ $0 != ".." && $0 != "." && !$0.isEmpty }) else {
            throw ContentLoadError.missingResource(path: path)
        }

        var url = root.standardizedFileURL
        for (index, part) in parts.enumerated() {
            let isLast = index == parts.count - 1
            url.appendPathComponent(part, isDirectory: !isLast)
        }

        let standardized = url.standardizedFileURL
        let rootPath = root.standardizedFileURL.path
        guard standardized.path == rootPath || standardized.path.hasPrefix(rootPath + "/") else {
            throw ContentLoadError.missingResource(path: path)
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else {
            throw ContentLoadError.missingResource(path: path)
        }
        return standardized
    }
}
