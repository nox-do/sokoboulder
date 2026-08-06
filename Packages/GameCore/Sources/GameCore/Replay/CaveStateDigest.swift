import CryptoKit
import Foundation

/// Stable SHA-256 digest of a ``CaveState`` for replay golden tests.
///
/// Never uses Swift's process-dependent `Hasher`. Canonical UTF-8 document
/// (no trailing newline):
/// ```
/// <width>x<height>
/// <status>
/// <tick>
/// <score>
/// <collected>/<required>
/// <remainingTicks>
/// <nextEntityID>
/// <player...>
/// <terrain row-major glyphs>
/// <occupantID,kind,motionOrHeading,column,row>  // ascending by id
/// ```
/// Gravity occupants use motion (`resting`/`falling`); enemies use heading.
public enum CaveStateDigest {
    public static func sha256Hex(_ state: CaveState) -> String {
        sha256Hex(utf8: canonicalString(state))
    }

    public static func canonicalString(_ state: CaveState) -> String {
        var lines: [String] = [
            "\(state.grid.width)x\(state.grid.height)",
            statusToken(state.status),
            String(state.tick),
            String(state.score),
            "\(state.collectedDiamonds)/\(state.requiredDiamonds)",
            String(state.remainingTicks),
            String(state.nextEntityID),
            playerToken(state.player, id: state.playerID),
        ]

        for row in 0..<state.grid.height {
            var glyphRow = ""
            for column in 0..<state.grid.width {
                let cell = state.grid[GridPosition(column: column, row: row)]
                glyphRow.append(terrainGlyph(cell.terrain))
            }
            lines.append(glyphRow)
        }

        var occupants: [(UInt64, String, String, Int, Int)] = []
        for row in 0..<state.grid.height {
            for column in 0..<state.grid.width {
                let position = GridPosition(column: column, row: row)
                guard let occupant = state.grid[position].occupant else { continue }
                occupants.append(
                    (
                        occupant.id.rawValue,
                        kindToken(occupant),
                        occupantStateToken(occupant),
                        column,
                        row
                    )
                )
            }
        }
        occupants.sort { $0.0 < $1.0 }
        for entry in occupants {
            lines.append("\(entry.0),\(entry.1),\(entry.2),\(entry.3),\(entry.4)")
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

    private static func playerToken(_ player: CavePlayerState, id: EntityID) -> String {
        switch player {
        case .alive(let position):
            "alive,\(id.rawValue),\(position.column),\(position.row)"
        case .dead(let position):
            "dead,\(id.rawValue),\(position.column),\(position.row)"
        }
    }

    private static func terrainGlyph(_ terrain: CaveTerrain) -> Character {
        switch terrain {
        case .void: "-"
        case .floor: " "
        case .dirt: "."
        case .wall: "#"
        case .steelWall: "X"
        case .exit(.closed): "E"
        case .exit(.open): "e"
        }
    }

    private static func kindToken(_ occupant: CaveOccupant) -> String {
        switch occupant {
        case .boulder: "boulder"
        case .diamond: "diamond"
        case .firefly: "firefly"
        case .butterfly: "butterfly"
        }
    }

    private static func motionToken(_ motion: FallingState) -> String {
        switch motion {
        case .resting: "resting"
        case .falling: "falling"
        }
    }

    private static func headingToken(_ heading: Direction) -> String {
        switch heading {
        case .up: "up"
        case .down: "down"
        case .left: "left"
        case .right: "right"
        }
    }

    private static func occupantStateToken(_ occupant: CaveOccupant) -> String {
        if let motion = occupant.motion {
            return motionToken(motion)
        }
        if let heading = occupant.heading {
            return headingToken(heading)
        }
        return "none"
    }
}
