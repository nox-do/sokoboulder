import CryptoKit
import Foundation

/// SHA-256 content hash for gameplay-relevant Cave level data.
///
/// Canonical UTF-8 document (no trailing newline after the last line):
/// ```
/// cave
/// 1
/// <map rows joined by \n>
/// <canonical rules JSON>
/// ```
public enum CaveContentHasher {
    public static func sha256Hex(
        game: LevelGameKind = .cave,
        schemaVersion: Int = CaveLevelFileV1.currentSchemaVersion,
        map: CaveASCIIMap,
        rules: CaveLevelRulesV1
    ) -> String {
        sha256Hex(utf8: canonicalString(
            game: game,
            schemaVersion: schemaVersion,
            rows: map.rows,
            rules: rules
        ))
    }

    public static func canonicalString(
        game: LevelGameKind,
        schemaVersion: Int,
        rows: [String],
        rules: CaveLevelRulesV1
    ) -> String {
        let lines = [game.rawValue, String(schemaVersion)] + rows + [rules.canonicalJSON]
        return lines.joined(separator: "\n")
    }

    public static func sha256Hex(utf8 string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
