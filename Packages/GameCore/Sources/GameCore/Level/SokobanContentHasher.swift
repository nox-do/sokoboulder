import CryptoKit
import Foundation

/// SHA-256 content hash for Sokoban level ASCII.
///
/// Uses a canonical encoding: map rows joined by `\n` (no trailing newline),
/// UTF-8 bytes. Never uses `Hashable` / Swift's `Hasher`.
public enum SokobanContentHasher {
    /// Hashes already-parsed map rows.
    public static func sha256Hex(map: SokobanASCIIMap) -> String {
        let canonical = map.rows.joined(separator: "\n")
        return sha256Hex(utf8: canonical)
    }

    /// Parses `ascii`, then hashes the canonical map encoding.
    public static func sha256Hex(ascii: String) throws -> String {
        let map = try SokobanASCIIParser.parse(ascii)
        return sha256Hex(map: map)
    }

    public static func sha256Hex(utf8 string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
