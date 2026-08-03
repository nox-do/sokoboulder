/// Presence used by cave movement, gravity, and collision rules.
///
/// The living player is never stored in ``CaveCell/occupant``; every rule must
/// use this query instead of `occupant == nil`.
enum CavePresence: Equatable {
    case empty
    case player
    case occupant(CaveOccupant)
    case blocked
}

enum CaveWorldQuery {
    static func presence(in state: CaveState, at position: GridPosition) -> CavePresence {
        guard state.grid.contains(position) else { return .blocked }
        if case .alive(let playerPosition) = state.player, playerPosition == position {
            return .player
        }
        let cell = state.grid[position]
        if let occupant = cell.occupant {
            return .occupant(occupant)
        }
        guard cell.isGravityEmptyTerrain else {
            return .blocked
        }
        return .empty
    }

    /// Whether a falling/rolling object may enter this cell.
    static func isGravityPassable(in state: CaveState, at position: GridPosition) -> Bool {
        switch presence(in: state, at: position) {
        case .empty, .player: true
        case .occupant, .blocked: false
        }
    }

    /// Resting objects treat the living player as solid support; falling ones may enter.
    static func canFallInto(in state: CaveState, at position: GridPosition, motion: FallingState) -> Bool {
        switch presence(in: state, at: position) {
        case .empty:
            return true
        case .player:
            return motion == .falling
        case .occupant, .blocked:
            return false
        }
    }

    static func isRoundSupport(_ presence: CavePresence) -> Bool {
        if case .occupant(let occupant) = presence {
            return occupant.isRoundSupport
        }
        return false
    }
}
