import GameCore

/// First playable cave demo (ASCII). Dig dirt, push/fall rocks, collect, exit.
enum CaveDemoLevel {
    static let id = "cave.demo.001"
    static let title = "Erste Höhle"

    static let ascii = """
        ##############
        #............#
        #..O....*....#
        #......O.....#
        #............#
        #..P.........#
        #............#
        #...........E#
        ##############
        """

    static func makeLevel() throws -> CaveLevel {
        try CaveLevelBuilder.level(
            fromASCII: ascii,
            requiredDiamonds: 1,
            timeLimitTicks: 600,
            diamondValue: 10,
            extraDiamondValue: 15
        )
    }
}
