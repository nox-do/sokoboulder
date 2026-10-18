import GameCore

/// Golden move sequences for catalog levels (tests / acceptance).
enum SokobanTutorialSolutions {
    /// Walk to the crate, then push it once across floor and once onto the goal.
    static let level001: [Direction] = [.right, .right, .right]

    /// Walk around the pillar, then push the crate onto the goal.
    static let level002: [Direction] = [
        .right, .up, .up, .right, .down,
    ]

    /// Two crates onto two goals without locking them against each other.
    static let level003: [Direction] = [
        .right, .down, .left, .down, .right, .up, .right, .up, .right, .down,
    ]
}
