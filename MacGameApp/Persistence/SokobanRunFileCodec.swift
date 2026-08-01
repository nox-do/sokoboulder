import Foundation

enum SokobanRunCodecError: Error, Equatable, Sendable {
    case unsupportedStatus
    case fileTooLarge(byteCount: Int)
    case decodingFailed
    case encodingFailed
}

/// Canonical JSON codec for ``SokobanRunFileV1``.
enum SokobanRunFileCodec {
    static let maxFileByteCount = 256 * 1024

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    /// Encodes with sorted keys, pretty printing, UTF-8, and a trailing newline.
    static func encode(_ file: SokobanRunFileV1) throws -> Data {
        let encoded: Data
        do {
            encoded = try makeEncoder().encode(file)
        } catch {
            throw SokobanRunCodecError.encodingFailed
        }
        var data = encoded
        if data.last != UInt8(ascii: "\n") {
            data.append(UInt8(ascii: "\n"))
        }
        return data
    }

    static func decode(_ data: Data) throws -> SokobanRunFileV1 {
        guard data.count <= maxFileByteCount else {
            throw SokobanRunCodecError.fileTooLarge(byteCount: data.count)
        }
        do {
            return try makeDecoder().decode(SokobanRunFileV1.self, from: data)
        } catch {
            throw SokobanRunCodecError.decodingFailed
        }
    }
}
