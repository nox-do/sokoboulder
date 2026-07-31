/// Integer cell coordinate on the logical game grid.
///
/// Convention: `(0, 0)` is the top-left cell. Columns increase to the right,
/// rows increase downward. SpriteKit coordinate conversion belongs in the renderer.
public struct GridPosition: Hashable, Codable, Sendable {
    public let column: Int
    public let row: Int

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }

    /// Returns the neighboring position one step in `direction`.
    public func neighbor(in direction: Direction) -> GridPosition {
        GridPosition(
            column: column + direction.columnOffset,
            row: row + direction.rowOffset
        )
    }
}
