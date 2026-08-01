import Foundation

enum ProgressCodecError: Error, Equatable, Sendable {
    case fileTooLarge(byteCount: Int)
    case decodingFailed
    case encodingFailed
    case unsupportedSchemaVersion(Int)
    case ioFailed(String)
}

/// Canonical JSON codec for ``ProgressFileV1``.
enum ProgressFileCodec {
    static let maxFileByteCount = 256 * 1024

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    static func encode(_ file: ProgressFileV1) throws -> Data {
        let encoded: Data
        do {
            encoded = try makeEncoder().encode(file)
        } catch {
            throw ProgressCodecError.encodingFailed
        }
        var data = encoded
        if data.last != UInt8(ascii: "\n") {
            data.append(UInt8(ascii: "\n"))
        }
        return data
    }

    static func decode(_ data: Data) throws -> ProgressFileV1 {
        guard data.count <= maxFileByteCount else {
            throw ProgressCodecError.fileTooLarge(byteCount: data.count)
        }
        let file: ProgressFileV1
        do {
            file = try makeDecoder().decode(ProgressFileV1.self, from: data)
        } catch {
            throw ProgressCodecError.decodingFailed
        }
        guard file.schemaVersion == ProgressFileV1.currentSchemaVersion else {
            throw ProgressCodecError.unsupportedSchemaVersion(file.schemaVersion)
        }
        return file
    }

    /// Reads only `schemaVersion` so newer files are not forced through the V1 DTO.
    static func peekSchemaVersion(_ data: Data) -> Int? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any]
        else {
            return nil
        }
        if let value = dictionary["schemaVersion"] as? Int {
            return value
        }
        if let number = dictionary["schemaVersion"] as? NSNumber {
            return number.intValue
        }
        return nil
    }

    static func atomicWrite(_ file: ProgressFileV1, to fileURL: URL) throws {
        let fileManager = FileManager.default
        let data: Data
        do {
            data = try encode(file)
        } catch {
            throw ProgressCodecError.encodingFailed
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
            throw ProgressCodecError.ioFailed(String(describing: error))
        }
    }
}
