import CryptoKit
import Foundation

/// SHA-256 content hash for gameplay-relevant Sokoban level data.
///
/// Canonical UTF-8 document (no trailing newline after the last line):
/// ```
/// sokoban
/// 1
/// <map rows joined by \n>
/// {}
/// ```
/// That is: `game`, `schemaVersion`, map rows, then canonical rules JSON.
///
/// Titles, string IDs, textures, and audio are excluded. Never uses Swift's
/// process-dependent `Hasher`.
public enum SokobanContentHasher {
    /// Hashes canonical gameplay content for a decoded map + rules.
    public static func sha256Hex(
        game: LevelGameKind = .sokoban,
        schemaVersion: Int = SokobanLevelFileV1.currentSchemaVersion,
        map: SokobanASCIIMap,
        rules: SokobanLevelRulesV1 = SokobanLevelRulesV1()
    ) -> String {
        sha256Hex(utf8: canonicalString(
            game: game,
            schemaVersion: schemaVersion,
            rows: map.rows,
            rules: rules
        ))
    }

    /// Convenience: parse ASCII rows, then hash with default Sokoban V1 rules.
    public static func sha256Hex(ascii: String) throws -> String {
        let map = try SokobanASCIIParser.parse(ascii)
        return sha256Hex(map: map)
    }

    /// Builds the exact UTF-8 string that is hashed.
    public static func canonicalString(
        game: LevelGameKind,
        schemaVersion: Int,
        rows: [String],
        rules: SokobanLevelRulesV1
    ) -> String {
        let lines = [game.rawValue, String(schemaVersion)] + rows + [rules.canonicalJSON]
        return lines.joined(separator: "\n")
    }

    public static func sha256Hex(utf8 string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
