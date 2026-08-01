import GameCore

/// Built-in Sokoban tutorial catalog with stable IDs and content hashes.
///
/// Level geometry matches the Phase-2 tutorial cuts (GAMEPLAY §4.2 / step 9).
/// Hashes are fixed once ASCII is final — do not casually edit rows.
enum SokobanLevelCatalog {
    static let tutorial: [SokobanLevelDescriptor] = {
        do {
            return [
                try SokobanLevelDescriptor(
                    id: "sokoban.tutorial.001",
                    title: "Der erste Schub",
                    ascii: """
                        #####
                        #@$.#
                        #####
                        """,
                    tutorialHintID: "hint.sokoban.move_and_push"
                ),
                try SokobanLevelDescriptor(
                    id: "sokoban.tutorial.002",
                    title: "Umweg und Undo",
                    ascii: """
                        #######
                        #     #
                        # # $ #
                        # @ . #
                        #######
                        """,
                    tutorialHintID: "hint.sokoban.walk_around_and_undo"
                ),
                try SokobanLevelDescriptor(
                    id: "sokoban.tutorial.003",
                    title: "Zwei Kisten",
                    ascii: """
                        ######
                        #@   #
                        # $$ #
                        #  ..#
                        ######
                        """,
                    tutorialHintID: "hint.sokoban.crate_blocking"
                ),
            ]
        } catch {
            preconditionFailure("Built-in Sokoban catalog must be valid: \(error)")
        }
    }()

    static var first: SokobanLevelDescriptor {
        tutorial[0]
    }

    static func descriptor(id: String) -> SokobanLevelDescriptor? {
        tutorial.first { $0.id == id }
    }

    static func index(of id: String) -> Int? {
        tutorial.firstIndex { $0.id == id }
    }

    static func descriptor(after id: String) -> SokobanLevelDescriptor? {
        guard let index = index(of: id), index + 1 < tutorial.count else {
            return nil
        }
        return tutorial[index + 1]
    }
}

/// Golden move sequences for catalog levels (tests / step-9 acceptance).
enum SokobanTutorialSolutions {
    static let level001: [Direction] = [.right]

    /// Walk around the pillar, then push the crate onto the goal.
    static let level002: [Direction] = [
        .right, .up, .up, .right, .down,
    ]

    /// Two crates onto two goals without locking them against each other.
    static let level003: [Direction] = [
        .right, .down, .left, .down, .right, .up, .right, .up, .right, .down,
    ]
}
