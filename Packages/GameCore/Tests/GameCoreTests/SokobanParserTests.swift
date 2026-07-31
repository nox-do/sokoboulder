import Testing
@testable import GameCore

@Suite("SokobanASCIIParser")
struct SokobanASCIIParserTests {
    @Test("parses a rectangular map and preserves spaces")
    func parsesRectangularMap() throws {
        let map = try SokobanASCIIParser.parse("#####\n#@$.#\n#####\n")
        #expect(map.width == 5)
        #expect(map.height == 3)
        #expect(map.rows[1] == "#@$.#")
    }

    @Test("does not trim trailing spaces inside a row")
    func preservesTrailingSpaces() throws {
        let map = try SokobanASCIIParser.parse("#@  \n####")
        #expect(map.width == 4)
        #expect(map.rows[0] == "#@  ")
    }

    @Test("rejects empty input")
    func emptyInput() {
        #expect(throws: SokobanParseError.emptyInput) {
            try SokobanASCIIParser.parse("")
        }
        #expect(throws: SokobanParseError.emptyInput) {
            try SokobanASCIIParser.parse("\n")
        }
    }

    @Test("rejects inconsistent row widths with line number")
    func inconsistentWidth() {
        #expect(
            throws: SokobanParseError.inconsistentRowWidth(line: 2, expected: 3, actual: 2)
        ) {
            try SokobanASCIIParser.parse("###\n##\n###")
        }
    }

    @Test("rejects unknown characters with location")
    func unknownCharacter() {
        #expect(
            throws: SokobanParseError.unknownCharacter("X", at: SourceLocation(line: 1, column: 2))
        ) {
            try SokobanASCIIParser.parse("#X#")
        }
    }

    @Test("accepts void glyph")
    func acceptsVoid() throws {
        let map = try SokobanASCIIParser.parse("---\n-@.\n-$-\n---")
        #expect(map.rows[0] == "---")
    }
}

@Suite("SokobanLevelValidator")
struct SokobanLevelValidatorTests {
    @Test("accepts a minimal valid level")
    func validLevel() throws {
        let level = try SokobanLevelValidator.level(fromASCII: """
            ####
            #@$#
            # .#
            ####
            """)
        #expect(level.width == 4)
        #expect(level.height == 4)
        #expect(level.playerStart == GridPosition(column: 1, row: 1))
        #expect(level.crateStarts == [GridPosition(column: 2, row: 1)])
        #expect(level.goalCount == 1)
        #expect(level.terrain[GridPosition(column: 2, row: 2)] == .goal)
        #expect(level.terrain[GridPosition(column: 1, row: 1)] == .floor)
    }

    @Test("decodes combined glyphs and void")
    func combinedGlyphs() throws {
        let level = try SokobanLevelValidator.level(fromASCII: """
            -----
            -+$*-
            -----
            """)
        #expect(level.playerStart == GridPosition(column: 1, row: 1))
        #expect(level.terrain[level.playerStart] == .goal)
        #expect(level.crateStarts == [
            GridPosition(column: 2, row: 1),
            GridPosition(column: 3, row: 1),
        ])
        #expect(level.terrain[GridPosition(column: 2, row: 1)] == .floor)
        #expect(level.terrain[GridPosition(column: 3, row: 1)] == .goal)
        #expect(level.terrain[GridPosition(column: 0, row: 0)] == .void)
        #expect(level.goalCount == 2)
    }

    @Test("rejects missing player")
    func noPlayer() throws {
        let map = try SokobanASCIIParser.parse("####\n#$.#\n####")
        #expect(throws: SokobanValidationError.noPlayer) {
            try SokobanLevelValidator.validate(map)
        }
    }

    @Test("rejects multiple players with locations")
    func multiplePlayers() throws {
        let map = try SokobanASCIIParser.parse("#####\n#@$@#\n#...#\n#####")
        #expect(
            throws: SokobanValidationError.multiplePlayers([
                SourceLocation(line: 2, column: 2),
                SourceLocation(line: 2, column: 4),
            ])
        ) {
            try SokobanLevelValidator.validate(map)
        }
    }

    @Test("rejects levels without goals")
    func noGoals() throws {
        let map = try SokobanASCIIParser.parse("####\n#@$#\n####")
        #expect(throws: SokobanValidationError.noGoals) {
            try SokobanLevelValidator.validate(map)
        }
    }

    @Test("rejects crate and goal count mismatch")
    func crateGoalMismatch() throws {
        let map = try SokobanASCIIParser.parse("#####\n#@$ #\n#.. #\n#####")
        #expect(throws: SokobanValidationError.crateGoalMismatch(crates: 1, goals: 2)) {
            try SokobanLevelValidator.validate(map)
        }
    }

    @Test("does not reject a corner crate")
    func allowsCornerCrate() throws {
        let level = try SokobanLevelValidator.level(fromASCII: """
            ###
            #$#
            #@.
            ###
            """)
        #expect(level.crateStarts.count == 1)
    }
}
