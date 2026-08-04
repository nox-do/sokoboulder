import Foundation

/// One row in the shared Sokoban / Cave level-selection overlay.
struct LevelSelectionRow: Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let availability: LevelAvailability
}
