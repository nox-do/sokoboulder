import Foundation
import GameCore

/// Versioned on-disk Sokoban run (schema 1).
///
/// Not a coded ``GameSession`` or ``SokobanState``. Terrain comes from the catalog.
struct SokobanRunFileV1: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let levelID: String
    let contentHash: String
    let ruleVersion: Int
    let checkpoint: SokobanCheckpointV1
    let commands: [SokobanDirectionV1]
    let cursor: Int
}

/// Versioned checkpoint payload embedded in ``SokobanRunFileV1``.
struct SokobanCheckpointV1: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let playerColumn: Int
    let playerRow: Int
    /// Sorted by ascending `id` when encoded.
    let crates: [SokobanCratePlacementV1]
    let moveCount: Int
    let pushCount: Int
    let status: SokobanPlayStatusV1
}

struct SokobanCratePlacementV1: Codable, Equatable, Sendable {
    let id: UInt64
    let column: Int
    let row: Int
}

/// Explicit string-backed direction for run files.
enum SokobanDirectionV1: String, Codable, Equatable, Sendable {
    case up
    case down
    case left
    case right

    init(_ direction: Direction) {
        switch direction {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        }
    }

    var direction: Direction {
        switch self {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        }
    }
}

/// Sokoban-only status values for V1 run files (no `failed`).
enum SokobanPlayStatusV1: String, Codable, Equatable, Sendable {
    case playing
    case completed

    init(_ status: PlayStatus) throws {
        switch status {
        case .playing: self = .playing
        case .completed: self = .completed
        case .failed:
            throw SokobanRunCodecError.unsupportedStatus
        }
    }

    var playStatus: PlayStatus {
        switch self {
        case .playing: .playing
        case .completed: .completed
        }
    }
}

extension SokobanCheckpointV1 {
    init(semantic: SokobanCheckpoint) throws {
        schemaVersion = Self.currentSchemaVersion
        playerColumn = semantic.playerPosition.column
        playerRow = semantic.playerPosition.row
        crates = semantic.crates.map {
            SokobanCratePlacementV1(
                id: $0.id.rawValue,
                column: $0.position.column,
                row: $0.position.row
            )
        }
        moveCount = semantic.moveCount
        pushCount = semantic.pushCount
        status = try SokobanPlayStatusV1(semantic.status)
    }

    var semantic: SokobanCheckpoint {
        SokobanCheckpoint(
            playerPosition: GridPosition(column: playerColumn, row: playerRow),
            crates: crates.map {
                SokobanCratePlacement(
                    id: EntityID($0.id),
                    position: GridPosition(column: $0.column, row: $0.row)
                )
            },
            moveCount: moveCount,
            pushCount: pushCount,
            status: status.playStatus
        )
    }
}
