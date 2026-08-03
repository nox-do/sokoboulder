import GameCore

/// Phase-4 demo caves (ASCII). One mechanic per level; no enemies.
struct CaveDemoDescriptor: Equatable, Sendable {
    var id: String
    var title: String
    var tutorialHint: String
    var ascii: String
    var requiredDiamonds: Int
    var timeLimitTicks: Int
    var diamondValue: Int
    var extraDiamondValue: Int

    func makeLevel() throws -> CaveLevel {
        try CaveLevelBuilder.level(
            fromASCII: ascii,
            requiredDiamonds: requiredDiamonds,
            timeLimitTicks: timeLimitTicks,
            diamondValue: diamondValue,
            extraDiamondValue: extraDiamondValue
        )
    }
}

enum CaveDemoCatalog {
    static let levels: [CaveDemoDescriptor] = [
        CaveDemoDescriptor(
            id: "cave.demo.001",
            title: "Der erste Diamant",
            tutorialHint: "Grabe dich durch die Erde und sammle den Diamanten. Danach öffnet sich der Ausgang.",
            ascii: """
                ############
                #P.........#
                #..........#
                #....*.....#
                #..........#
                #.......E..#
                #..........#
                ############
                """,
            requiredDiamonds: 1,
            timeLimitTicks: 900,
            diamondValue: 10,
            extraDiamondValue: 15
        ),
        CaveDemoDescriptor(
            id: "cave.demo.002",
            title: "Unter dem Felsen",
            tutorialHint:
                "Ein ruhender Fels über dir ist ungefährlich. Sobald du seinen Platz freigibst, fällt er nach unten.",
            ascii: """
                ##############
                #............#
                #....O.......#
                #....P..*....#
                #............#
                #.........E..#
                #............#
                ##############
                """,
            requiredDiamonds: 1,
            timeLimitTicks: 750,
            diamondValue: 10,
            extraDiamondValue: 15
        ),
        CaveDemoDescriptor(
            id: "cave.demo.003",
            title: "Der Felsschacht",
            tutorialHint:
                "Felsen lassen sich nur seitlich schieben. Schiebe den Fels über den Schacht, damit er nach unten fällt und den Weg freigibt.",
            ascii: """
                ##############
                #P...........#
                #............#
                #..#####.....#
                #..O   #..*..#
                #..## ##.....#
                #.....*....E.#
                #............#
                ##############
                """,
            requiredDiamonds: 2,
            timeLimitTicks: 600,
            diamondValue: 10,
            extraDiamondValue: 15
        ),
    ]

    static var first: CaveDemoDescriptor { levels[0] }

    static func descriptor(id: String) -> CaveDemoDescriptor? {
        levels.first { $0.id == id }
    }

    static func descriptor(after id: String) -> CaveDemoDescriptor? {
        guard let index = levels.firstIndex(where: { $0.id == id }) else { return nil }
        let next = levels.index(after: index)
        guard next < levels.endIndex else { return nil }
        return levels[next]
    }
}

/// Compatibility for existing call sites / tests (first demo).
enum CaveDemoLevel {
    static var id: String { CaveDemoCatalog.first.id }
    static var title: String { CaveDemoCatalog.first.title }

    static func makeLevel() throws -> CaveLevel {
        try CaveDemoCatalog.first.makeLevel()
    }
}
