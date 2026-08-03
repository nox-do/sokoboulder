import Foundation
import Testing
@testable import GameCore

@Suite("Sokoban state digest")
struct SokobanStateDigestTests {
    @Test("digest is stable for identical states and changes with a move")
    func stableAndSensitive() throws {
        let level = try SokobanLevelValidator.level(
            fromASCII: """
                #####
                #@$.#
                #####
                """
        )
        let rules = SokobanRules()
        let start = try rules.start(level: level)
        let a = SokobanStateDigest.sha256Hex(start)
        let b = SokobanStateDigest.sha256Hex(start)
        #expect(a == b)
        #expect(a.count == 64)
        #expect(a == a.lowercased())

        let pushed = try rules.move(.right, in: start)
        let after = SokobanStateDigest.sha256Hex(pushed.state)
        #expect(after != a)
    }
}

@Suite("Sokoban replay runner")
struct SokobanReplayRunnerTests {
    @Test("runner completes a short golden solution and verifies the file")
    func goldenRoundTrip() throws {
        let ascii = """
            #####
            # @ #
            #   #
            # $ #
            # . #
            #####
            """
        let level = try SokobanLevelValidator.level(fromASCII: ascii)
        let contentHash = try SokobanContentHasher.sha256Hex(ascii: ascii)
        let commands: [Direction] = [.down, .down]

        let file = try SokobanReplayRunner.makeFile(
            levelID: "replay.fixture.001",
            contentHash: contentHash,
            level: level,
            commands: commands
        )
        #expect(file.game == .sokoban)
        #expect(file.commands == ["down", "down"])
        #expect(file.expectedDigest.count == 64)

        let verified = try SokobanReplayRunner.verify(
            file,
            level: level,
            levelContentHash: contentHash
        )
        #expect(verified.state.status == .completed)
        #expect(verified.digest == file.expectedDigest)

        // Encode/decode round-trip preserves golden fields.
        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ReplayFileV1.self, from: data)
        #expect(decoded == file)
        _ = try SokobanReplayRunner.verify(
            decoded,
            level: level,
            levelContentHash: contentHash
        )
    }

    @Test("blocked commands are rejected by the runner")
    func rejectsBlockedCommands() throws {
        let level = try SokobanLevelValidator.level(
            fromASCII: """
                #####
                #@$.#
                #####
                """
        )
        #expect(throws: ReplayError.unexpectedOutcome(.up, .blocked)) {
            _ = try SokobanReplayRunner.run(level: level, commands: [.up])
        }
    }

    @Test("digest mismatch is reported")
    func digestMismatch() throws {
        let ascii = """
            #####
            #@$.#
            #####
            """
        let level = try SokobanLevelValidator.level(fromASCII: ascii)
        let contentHash = try SokobanContentHasher.sha256Hex(ascii: ascii)
        var file = try SokobanReplayRunner.makeFile(
            levelID: "replay.fixture.bad",
            contentHash: contentHash,
            level: level,
            commands: [.right]
        )
        file = ReplayFileV1(
            levelID: file.levelID,
            contentHash: file.contentHash,
            ruleVersion: file.ruleVersion,
            commands: [.right],
            expectedDigest: String(repeating: "0", count: 64)
        )
        #expect(throws: ReplayError.self) {
            _ = try SokobanReplayRunner.verify(
                file,
                level: level,
                levelContentHash: contentHash
            )
        }
    }
}
