import Foundation

/// Primary confirm action on the Sokoban result overlay (Return / Space).
enum OutcomePrimaryAction: Equatable, Sendable {
    /// Advance to the next catalog level (replaces the run file).
    case nextLevel(id: String)
    /// Campaign finished — return to the launch menu / game selection.
    case openLaunchMenu
    /// Restart the current cave demo.
    case playAgain
}
