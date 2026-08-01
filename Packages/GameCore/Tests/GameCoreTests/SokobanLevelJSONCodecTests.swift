import Testing
@testable import GameCore

@Suite("Sokoban level JSON V1")
struct SokobanLevelJSONCodecTests {
    private let introJSON = """
        {
          "schemaVersion": 1,
          "id": "sokoban.tutorial.001",
          "game": "sokoban",
          "titleID": "level.sokoban.tutorial.001.title",
          "tutorialHintID": "hint.sokoban.move_and_push",
          "width": 5,
          "height": 3,
          "rows": [
            "#####",
            "#@$.#",
            "#####"
          ],
          "rules": {}
        }
        """

    @Test("decodes and validates a tutorial level")
    func decodeValid() throws {
        let decoded = try SokobanLevelJSONCodec.decode(json: introJSON)
        #expect(decoded.file.id == "sokoban.tutorial.001")
        #expect(decoded.file.titleID == "level.sokoban.tutorial.001.title")
        #expect(decoded.level.width == 5)
        #expect(decoded.level.height == 3)
        #expect(decoded.contentHash.count == 64)
        #expect(decoded.contentHash == decoded.contentHash.lowercased())
    }

    @Test("content hash ignores presentation string IDs")
    func hashIgnoresPresentationIDs() throws {
        let a = try SokobanLevelJSONCodec.decode(json: introJSON)
        let altered = introJSON
            .replacingOccurrences(
                of: "level.sokoban.tutorial.001.title",
                with: "level.other.title"
            )
            .replacingOccurrences(
                of: "hint.sokoban.move_and_push",
                with: "hint.other"
            )
        let b = try SokobanLevelJSONCodec.decode(json: altered)
        #expect(a.contentHash == b.contentHash)
        #expect(a.file.titleID != b.file.titleID)
    }

    @Test("content hash includes game, schema, rows, and rules")
    func hashMatchesCanonicalDocument() throws {
        let decoded = try SokobanLevelJSONCodec.decode(json: introJSON)
        let canonical = SokobanContentHasher.canonicalString(
            game: .sokoban,
            schemaVersion: 1,
            rows: ["#####", "#@$.#", "#####"],
            rules: SokobanLevelRulesV1()
        )
        #expect(decoded.contentHash == SokobanContentHasher.sha256Hex(utf8: canonical))
        #expect(canonical == "sokoban\n1\n#####\n#@$.#\n#####\n{}")
    }

    @Test("rejects unsupported schema version")
    func rejectsNewerSchema() {
        let json = """
            {
              "schemaVersion": 99,
              "id": "x",
              "game": "sokoban",
              "titleID": "t",
              "width": 3,
              "height": 1,
              "rows": ["#@."],
              "rules": {}
            }
            """
        #expect(throws: SokobanLevelJSONError.unsupportedSchemaVersion(99)) {
            _ = try SokobanLevelJSONCodec.decode(json: json)
        }
    }

    @Test("rejects width/height mismatch")
    func rejectsDimensionMismatch() {
        let json = """
            {
              "schemaVersion": 1,
              "id": "x",
              "game": "sokoban",
              "titleID": "t",
              "width": 4,
              "height": 1,
              "rows": ["#@."],
              "rules": {}
            }
            """
        #expect(throws: SokobanLevelJSONError.self) {
            _ = try SokobanLevelJSONCodec.decode(json: json)
        }
    }

    @Test("rejects semantic validation errors")
    func rejectsNoGoals() {
        let json = """
            {
              "schemaVersion": 1,
              "id": "x",
              "game": "sokoban",
              "titleID": "t",
              "width": 3,
              "height": 1,
              "rows": ["#@#"],
              "rules": {}
            }
            """
        #expect(throws: SokobanLevelJSONError.self) {
            _ = try SokobanLevelJSONCodec.decode(json: json)
        }
    }

    @Test("rejects unknown top-level keys")
    func rejectsUnknownKeys() {
        let json = """
            {
              "schemaVersion": 1,
              "id": "x",
              "game": "sokoban",
              "titleID": "t",
              "tutorialHintId": "hint.typo",
              "width": 5,
              "height": 3,
              "rows": ["#####", "#@$.#", "#####"],
              "rules": {}
            }
            """
        #expect(throws: SokobanLevelJSONError.unknownKeys(["tutorialHintId"])) {
            _ = try SokobanLevelJSONCodec.decode(json: json)
        }
    }

    @Test("rejects missing required rules object")
    func rejectsMissingRules() {
        let json = """
            {
              "schemaVersion": 1,
              "id": "x",
              "game": "sokoban",
              "titleID": "t",
              "width": 5,
              "height": 3,
              "rows": ["#####", "#@$.#", "#####"]
            }
            """
        #expect(throws: SokobanLevelJSONError.missingKeys(["rules"])) {
            _ = try SokobanLevelJSONCodec.decode(json: json)
        }
    }

    @Test("rejects unknown fields inside rules")
    func rejectsUnknownRuleFields() {
        let json = """
            {
              "schemaVersion": 1,
              "id": "x",
              "game": "sokoban",
              "titleID": "t",
              "width": 5,
              "height": 3,
              "rows": ["#####", "#@$.#", "#####"],
              "rules": { "moveLimit": 20 }
            }
            """
        #expect(throws: SokobanLevelJSONError.unknownRuleKeys(["moveLimit"])) {
            _ = try SokobanLevelJSONCodec.decode(json: json)
        }
    }

    @Test("encode/decode round-trip preserves fields")
    func roundTrip() throws {
        let original = SokobanLevelFileV1(
            id: "sokoban.roundtrip",
            titleID: "level.roundtrip.title",
            goalTextID: "level.roundtrip.goal",
            tutorialHintID: "hint.roundtrip",
            width: 5,
            height: 3,
            rows: ["#####", "#@$.#", "#####"]
        )
        let data = try SokobanLevelJSONCodec.encode(original)
        let decoded = try SokobanLevelJSONCodec.decode(data)
        #expect(decoded.file.id == original.id)
        #expect(decoded.file.titleID == original.titleID)
        #expect(decoded.file.goalTextID == original.goalTextID)
        #expect(decoded.file.tutorialHintID == original.tutorialHintID)
        #expect(decoded.file.rows == original.rows)
    }
}
