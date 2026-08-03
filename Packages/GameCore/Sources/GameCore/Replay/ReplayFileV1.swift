import Foundation

/// Versioned debug/replay document (schema 1).
///
/// Sokoban V1 stores only the sequence of simulated directions. Cave will later
/// add tick-tagged intents without changing this Sokoban layout: bump
/// ``schemaVersion`` or introduce a dedicated cave DTO when needed.
///
/// Digests never include audio, themes, or timing epochs.
public struct ReplayFileV1: Equatable, Codable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let game: LevelGameKind
    public let levelID: String
    public let contentHash: String
    public let ruleVersion: Int
    /// Actually simulated Sokoban moves (blocked attempts are omitted).
    public let commands: [String]
    /// Expected ``SokobanStateDigest`` after replaying ``commands``.
    public let expectedDigest: String

    public init(
        schemaVersion: Int = currentSchemaVersion,
        game: LevelGameKind = .sokoban,
        levelID: String,
        contentHash: String,
        ruleVersion: Int = SokobanRules.ruleVersion,
        commands: [Direction],
        expectedDigest: String
    ) {
        self.schemaVersion = schemaVersion
        self.game = game
        self.levelID = levelID
        self.contentHash = contentHash
        self.ruleVersion = ruleVersion
        self.commands = commands.map(Self.encode)
        self.expectedDigest = expectedDigest
    }

    public func decodedCommands() throws -> [Direction] {
        try commands.map { token in
            guard let direction = Self.decode(token) else {
                throw ReplayError.invalidCommand(token)
            }
            return direction
        }
    }

    private static func encode(_ direction: Direction) -> String {
        switch direction {
        case .up: "up"
        case .down: "down"
        case .left: "left"
        case .right: "right"
        }
    }

    private static func decode(_ token: String) -> Direction? {
        switch token {
        case "up": .up
        case "down": .down
        case "left": .left
        case "right": .right
        default: nil
        }
    }
}

public enum ReplayError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
    case unsupportedGame(LevelGameKind)
    case ruleVersionMismatch(found: Int, expected: Int)
    case contentHashMismatch(found: String, expected: String)
    case invalidCommand(String)
    case digestMismatch(found: String, expected: String)
    case unexpectedOutcome(Direction, StepOutcome)
}
