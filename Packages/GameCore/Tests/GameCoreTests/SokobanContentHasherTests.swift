import Testing
@testable import GameCore

@Suite("Sokoban content hash")
struct SokobanContentHasherTests {
    @Test("canonical encoding includes game, schema, rows, and rules")
    func canonicalEncoding() throws {
        let ascii = """
            #####
            #@$.#
            #####
            """
        let map = try SokobanASCIIParser.parse(ascii)
        let expected = "sokoban\n1\n#####\n#@$.#\n#####\n{}"
        #expect(
            SokobanContentHasher.canonicalString(
                game: .sokoban,
                schemaVersion: 1,
                rows: map.rows,
                rules: SokobanLevelRulesV1()
            ) == expected
        )

        let hash = SokobanContentHasher.sha256Hex(map: map)
        #expect(hash == SokobanContentHasher.sha256Hex(utf8: expected))
        #expect(hash.count == 64)
        #expect(hash == hash.lowercased())
        #expect(try SokobanContentHasher.sha256Hex(ascii: ascii) == hash)
    }

    @Test("whitespace-significant rows change the hash")
    func whitespaceChangesHash() throws {
        let a = try SokobanContentHasher.sha256Hex(ascii: """
            ####
            #@.#
            ####
            """)
        let b = try SokobanContentHasher.sha256Hex(ascii: """
            #####
            #@. #
            #####
            """)
        #expect(a != b)
    }
}
