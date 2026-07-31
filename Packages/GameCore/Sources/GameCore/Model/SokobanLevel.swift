/// Validated, runtime-ready Sokoban level without runtime entity identities.
///
/// Crate and player ``EntityID`` values are assigned only by
/// ``SokobanRules/start(level:)``.
///
/// Construction is module-internal. Public callers obtain levels via
/// ``SokobanLevelValidator`` so documented invariants hold.
public struct SokobanLevel: Equatable, Sendable {
    public let terrain: Grid<SokobanTerrain>
    public let playerStart: GridPosition
    /// Crate start positions in deterministic row-major encounter order.
    public let crateStarts: [GridPosition]

    public var width: Int { terrain.width }
    public var height: Int { terrain.height }

    init(
        terrain: Grid<SokobanTerrain>,
        playerStart: GridPosition,
        crateStarts: [GridPosition]
    ) {
        self.terrain = terrain
        self.playerStart = playerStart
        self.crateStarts = crateStarts
    }

    public var goalCount: Int {
        var count = 0
        for row in 0..<height {
            for column in 0..<width {
                if terrain[GridPosition(column: column, row: row)] == .goal {
                    count += 1
                }
            }
        }
        return count
    }
}
