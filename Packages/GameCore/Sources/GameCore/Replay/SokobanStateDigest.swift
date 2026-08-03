import CryptoKit
import Foundation

/// Stable SHA-256 digest of a ``SokobanState`` for replay golden tests.
///
/// Never uses Swift's process-dependent `Hasher`. Canonical UTF-8 document
/// (no trailing newline):
/// ```
/// <width>x<height>
/// <status>
/// <moveCount>
/// <pushCount>
/// <playerID>
/// <playerColumn>,<playerRow>
/// <crateID>,<column>,<row>   // one line per crate, ascending by id
/// ```
public enum SokobanStateDigest {
    public static func sha256Hex(_ state: SokobanState) -> String {
        sha256Hex(utf8: canonicalString(state))
    }

    public static func canonicalString(_ state: SokobanState) -> String {
        var lines: [String] = [
            "\(state.grid.width)x\(state.grid.height)",
            statusToken(state.status),
            String(state.moveCount),
            String(state.pushCount),
            String(state.playerID.rawValue),
            "\(state.playerPosition.column),\(state.playerPosition.row)",
        ]

        var crates: [(UInt64, Int, Int)] = []
        for row in 0..<state.grid.height {
            for column in 0..<state.grid.width {
                let position = GridPosition(column: column, row: row)
                if case .crate(let id) = state.grid[position].occupant {
                    crates.append((id.rawValue, column, row))
                }
            }
        }
        crates.sort { $0.0 < $1.0 }
        for crate in crates {
            lines.append("\(crate.0),\(crate.1),\(crate.2)")
        }
        return lines.joined(separator: "\n")
    }

    public static func sha256Hex(utf8 string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func statusToken(_ status: PlayStatus) -> String {
        switch status {
        case .playing: "playing"
        case .completed: "completed"
        case .failed: "failed"
        }
    }
}
