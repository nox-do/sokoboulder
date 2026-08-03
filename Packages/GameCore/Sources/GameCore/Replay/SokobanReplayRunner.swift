import Foundation

/// Headless Sokoban replay runner (no renderer, no audio).
public enum SokobanReplayRunner {
    public struct Result: Equatable, Sendable {
        public let state: SokobanState
        public let digest: String
    }

    /// Replays changing moves only. Blocked outcomes are rejected so a stored
    /// command list stays identical to a productive journal.
    public static func run(
        level: SokobanLevel,
        commands: [Direction],
        rules: SokobanRules = SokobanRules()
    ) throws -> Result {
        var state = try rules.start(level: level)
        for direction in commands {
            let transition = try rules.move(direction, in: state)
            switch transition.outcome {
            case .changed, .terminal:
                state = transition.state
            case .blocked:
                throw ReplayError.unexpectedOutcome(direction, .blocked)
            }
        }
        let digest = SokobanStateDigest.sha256Hex(state)
        return Result(state: state, digest: digest)
    }

    /// Validates identity fields, then replays and checks the golden digest.
    public static func verify(
        _ file: ReplayFileV1,
        level: SokobanLevel,
        levelContentHash: String,
        rules: SokobanRules = SokobanRules()
    ) throws -> Result {
        guard file.schemaVersion == ReplayFileV1.currentSchemaVersion else {
            throw ReplayError.unsupportedSchemaVersion(file.schemaVersion)
        }
        guard file.game == .sokoban else {
            throw ReplayError.unsupportedGame(file.game)
        }
        guard file.ruleVersion == SokobanRules.ruleVersion else {
            throw ReplayError.ruleVersionMismatch(
                found: file.ruleVersion,
                expected: SokobanRules.ruleVersion
            )
        }
        guard file.contentHash == levelContentHash else {
            throw ReplayError.contentHashMismatch(
                found: file.contentHash,
                expected: levelContentHash
            )
        }

        let commands = try file.decodedCommands()
        let result = try run(level: level, commands: commands, rules: rules)
        guard result.digest == file.expectedDigest else {
            throw ReplayError.digestMismatch(
                found: result.digest,
                expected: file.expectedDigest
            )
        }
        return result
    }

    /// Builds a verified-ready replay from a productive command list.
    public static func makeFile(
        levelID: String,
        contentHash: String,
        level: SokobanLevel,
        commands: [Direction],
        rules: SokobanRules = SokobanRules()
    ) throws -> ReplayFileV1 {
        let result = try run(level: level, commands: commands, rules: rules)
        return ReplayFileV1(
            levelID: levelID,
            contentHash: contentHash,
            commands: commands,
            expectedDigest: result.digest
        )
    }
}
