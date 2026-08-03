import Foundation
import Testing
import GameCore

@Suite("Cave level JSON codec")
struct CaveLevelJSONCodecTests {
    @Test("demo 001 materializes with hash")
    func demoOne() throws {
        let decoded = try CaveLevelJSONCodec.decode(json: """
            {
              "schemaVersion": 1,
              "id": "cave.demo.001",
              "game": "cave",
              "titleID": "level.cave.demo.001.title",
              "tutorialHintID": "hint.cave.dig_and_collect",
              "width": 12,
              "height": 8,
              "rows": [
                "############",
                "#P.........#",
                "#..........#",
                "#....*.....#",
                "#..........#",
                "#.......E..#",
                "#..........#",
                "############"
              ],
              "rules": {
                "requiredDiamonds": 1,
                "timeLimitTicks": 900,
                "diamondValue": 10,
                "extraDiamondValue": 15
              }
            }
            """)
        #expect(decoded.file.id == "cave.demo.001")
        #expect(decoded.level.requiredDiamonds == 1)
        #expect(decoded.level.timeLimitTicks == 900)
        #expect(decoded.contentHash.count == 64)
    }

    @Test("unknown rule keys are rejected")
    func rejectsUnknownRules() {
        #expect(throws: CaveLevelJSONError.self) {
            _ = try CaveLevelJSONCodec.decode(json: """
                {
                  "schemaVersion": 1,
                  "id": "cave.bad",
                  "game": "cave",
                  "titleID": "t",
                  "width": 5,
                  "height": 3,
                  "rows": ["#####", "#P E#", "#####"],
                  "rules": { "requiredDiamonds": 0, "timeLimitTicks": 10, "snap": true }
                }
                """)
        }
    }

    @Test("sokoban game kind is rejected")
    func rejectsSokobanGame() {
        #expect(throws: CaveLevelJSONError.self) {
            _ = try CaveLevelJSONCodec.decode(json: """
                {
                  "schemaVersion": 1,
                  "id": "cave.bad",
                  "game": "sokoban",
                  "titleID": "t",
                  "width": 5,
                  "height": 3,
                  "rows": ["#####", "#P E#", "#####"],
                  "rules": { "requiredDiamonds": 0, "timeLimitTicks": 10 }
                }
                """)
        }
    }
}
