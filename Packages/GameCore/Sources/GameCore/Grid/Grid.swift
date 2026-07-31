/// Fixed-size two-dimensional cell storage used by game worlds.
///
/// Cells are addressed by ``GridPosition``. Positions outside
/// `0..<width` × `0..<height` are considered outside the grid; rule engines
/// treat those accesses as impermeable boundaries.
public struct Grid<Cell: Sendable>: Sendable {
    public let width: Int
    public let height: Int

    /// Row-major storage: index = `row * width + column`.
    private var cells: [Cell]

    /// Creates a grid filled with `value`.
    ///
    /// - Precondition: `width` and `height` are non-negative.
    public init(width: Int, height: Int, repeating value: Cell) {
        precondition(width >= 0, "Grid width must be non-negative")
        precondition(height >= 0, "Grid height must be non-negative")
        self.width = width
        self.height = height
        self.cells = Array(repeating: value, count: width * height)
    }

    /// Creates a grid from an existing row-major cell buffer.
    ///
    /// - Precondition: `width` and `height` are non-negative.
    /// - Precondition: `cells.count == width * height`.
    public init(width: Int, height: Int, cells: [Cell]) {
        precondition(width >= 0, "Grid width must be non-negative")
        precondition(height >= 0, "Grid height must be non-negative")
        precondition(
            cells.count == width * height,
            "Cell count must equal width * height"
        )
        self.width = width
        self.height = height
        self.cells = cells
    }

    /// Whether `position` lies inside the grid bounds.
    public func contains(_ position: GridPosition) -> Bool {
        position.column >= 0
            && position.row >= 0
            && position.column < width
            && position.row < height
    }

    /// Safe read that returns `nil` for out-of-bounds positions.
    public func cell(at position: GridPosition) -> Cell? {
        guard contains(position) else { return nil }
        return cells[index(of: position)]
    }

    public subscript(position: GridPosition) -> Cell {
        get {
            precondition(contains(position), "GridPosition out of bounds: \(position)")
            return cells[index(of: position)]
        }
        set {
            precondition(contains(position), "GridPosition out of bounds: \(position)")
            cells[index(of: position)] = newValue
        }
        _modify {
            precondition(contains(position), "GridPosition out of bounds: \(position)")
            yield &cells[index(of: position)]
        }
    }

    private func index(of position: GridPosition) -> Int {
        position.row * width + position.column
    }
}

extension Grid: Equatable where Cell: Equatable {}
extension Grid: Hashable where Cell: Hashable {}
extension Grid: Codable where Cell: Codable {}
