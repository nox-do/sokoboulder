/// Ordered domain events produced by a rule step.
///
/// Events describe what happened, not how to animate or play audio.
public enum GameEvent: Equatable, Sendable {
    case movementBlocked(at: GridPosition)
    case entityMoved(EntityRef, from: GridPosition, to: GridPosition)
    case objectPushed(EntityRef, from: GridPosition, to: GridPosition)
    case crateEnteredGoal(EntityRef, at: GridPosition, completed: Int, total: Int)
    case crateLeftGoal(EntityRef, at: GridPosition, completed: Int, total: Int)
    case objectStartedFalling(EntityRef, at: GridPosition)
    case objectLanded(EntityRef, at: GridPosition)
    case diamondCollected(EntityRef, at: GridPosition, total: Int)
    case exitOpened(at: GridPosition)
    case explosion(center: GridPosition, changes: [CellChange])
    case playerDied(at: GridPosition)
    case levelCompleted
    case timeExpired
}

/// Render content change for area effects (explosions). Unused in Phase 1 Sokoban.
public struct CellChange: Equatable, Sendable {
    public let position: GridPosition

    public init(position: GridPosition) {
        self.position = position
    }
}
