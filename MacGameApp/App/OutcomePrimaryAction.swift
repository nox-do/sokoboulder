import Foundation

/// Primary confirm action on the Sokoban result overlay (Return / Space).
enum OutcomePrimaryAction: Equatable, Sendable {
    /// Advance to the next catalog level (replaces the run file).
    case nextLevel(id: String)
    /// Tutorial finished — return to the start of the tutorial.
    case finishTutorial
}
