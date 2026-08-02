/// Conservative static analysis for crate start positions in authored levels.
///
/// Starting at every goal, this walks possible crate positions backwards. A
/// backwards step requires both the previous crate cell and the cell where the
/// player would have to stand to be walkable. Other crates and player access
/// are deliberately ignored, so every reported position is certainly dead;
/// the analysis may leave more complex deadlocks unreported.
public enum SokobanStaticDeadlockAnalyzer {
    public static func deadCrateStarts(in level: SokobanLevel) -> [GridPosition] {
        let deadSquares = staticDeadSquares(in: level)
        return level.crateStarts.filter { deadSquares.contains($0) }
    }

    /// Walkable cells from which a crate can never reach any goal, regardless
    /// of other crates. Suitable for authoring checks and guaranteed runtime
    /// deadlocks; it intentionally does not claim more complex deadlocks.
    public static func staticDeadSquares(in level: SokobanLevel) -> Set<GridPosition> {
        let goalReachable = cratePositionsThatCanReachAGoal(in: level)
        var deadSquares = Set<GridPosition>()
        for row in 0..<level.height {
            for column in 0..<level.width {
                let position = GridPosition(column: column, row: row)
                if isWalkable(position, in: level), !goalReachable.contains(position) {
                    deadSquares.insert(position)
                }
            }
        }
        return deadSquares
    }

    private static func cratePositionsThatCanReachAGoal(
        in level: SokobanLevel
    ) -> Set<GridPosition> {
        var reachable = Set<GridPosition>()
        var queue: [GridPosition] = []

        for row in 0..<level.height {
            for column in 0..<level.width {
                let position = GridPosition(column: column, row: row)
                if level.terrain[position] == .goal {
                    reachable.insert(position)
                    queue.append(position)
                }
            }
        }

        var index = 0
        while index < queue.count {
            let destination = queue[index]
            index += 1

            for pushDirection in Direction.allCases {
                let previous = destination.neighbor(in: pushDirection.opposite)
                let playerSupport = previous.neighbor(in: pushDirection.opposite)
                guard isWalkable(previous, in: level),
                    isWalkable(playerSupport, in: level),
                    reachable.insert(previous).inserted
                else { continue }
                queue.append(previous)
            }
        }

        return reachable
    }

    private static func isWalkable(
        _ position: GridPosition,
        in level: SokobanLevel
    ) -> Bool {
        guard let terrain = level.terrain.cell(at: position) else { return false }
        return terrain == .floor || terrain == .goal
    }
}
