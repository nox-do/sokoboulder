import Foundation
import Testing
@testable import GameCore

@Suite("GridPosition")
struct GridPositionTests {
    @Test("stores column and row")
    func storesCoordinates() {
        let position = GridPosition(column: 3, row: 5)
        #expect(position.column == 3)
        #expect(position.row == 5)
    }

    @Test("neighbor follows model axes with (0,0) at top-left")
    func neighborOffsets() {
        let origin = GridPosition(column: 2, row: 2)
        #expect(origin.neighbor(in: .up) == GridPosition(column: 2, row: 1))
        #expect(origin.neighbor(in: .down) == GridPosition(column: 2, row: 3))
        #expect(origin.neighbor(in: .left) == GridPosition(column: 1, row: 2))
        #expect(origin.neighbor(in: .right) == GridPosition(column: 3, row: 2))
    }

    @Test("is Hashable and Codable")
    func hashableAndCodable() throws {
        let position = GridPosition(column: 1, row: 4)
        var set: Set<GridPosition> = []
        set.insert(position)
        #expect(set.contains(GridPosition(column: 1, row: 4)))

        let data = try JSONEncoder().encode(position)
        let decoded = try JSONDecoder().decode(GridPosition.self, from: data)
        #expect(decoded == position)
    }
}

@Suite("Direction")
struct DirectionTests {
    @Test("offsets match grid convention")
    func offsets() {
        #expect(Direction.up.columnOffset == 0)
        #expect(Direction.up.rowOffset == -1)
        #expect(Direction.down.columnOffset == 0)
        #expect(Direction.down.rowOffset == 1)
        #expect(Direction.left.columnOffset == -1)
        #expect(Direction.left.rowOffset == 0)
        #expect(Direction.right.columnOffset == 1)
        #expect(Direction.right.rowOffset == 0)
    }

    @Test("opposite pairs")
    func opposite() {
        #expect(Direction.up.opposite == .down)
        #expect(Direction.down.opposite == .up)
        #expect(Direction.left.opposite == .right)
        #expect(Direction.right.opposite == .left)
    }

    @Test("allCases covers four cardinals")
    func allCases() {
        #expect(Direction.allCases.count == 4)
        #expect(Set(Direction.allCases) == [.up, .down, .left, .right])
    }
}

@Suite("Grid")
struct GridTests {
    @Test("repeating initializer fills every cell")
    func repeatingInitializer() {
        var grid = Grid(width: 3, height: 2, repeating: 0)
        #expect(grid.width == 3)
        #expect(grid.height == 2)

        for row in 0..<2 {
            for column in 0..<3 {
                #expect(grid[GridPosition(column: column, row: row)] == 0)
            }
        }

        grid[GridPosition(column: 1, row: 0)] = 7
        #expect(grid[GridPosition(column: 1, row: 0)] == 7)
        #expect(grid[GridPosition(column: 0, row: 0)] == 0)
    }

    @Test("row-major cells initializer preserves layout")
    func cellsInitializer() {
        // 1 2 3
        // 4 5 6
        let grid = Grid(width: 3, height: 2, cells: [1, 2, 3, 4, 5, 6])
        #expect(grid[GridPosition(column: 0, row: 0)] == 1)
        #expect(grid[GridPosition(column: 2, row: 0)] == 3)
        #expect(grid[GridPosition(column: 0, row: 1)] == 4)
        #expect(grid[GridPosition(column: 2, row: 1)] == 6)
    }

    @Test("contains reports in- and out-of-bounds positions")
    func containsBounds() {
        let grid = Grid(width: 2, height: 3, repeating: ".")
        #expect(grid.contains(GridPosition(column: 0, row: 0)))
        #expect(grid.contains(GridPosition(column: 1, row: 2)))
        #expect(!grid.contains(GridPosition(column: -1, row: 0)))
        #expect(!grid.contains(GridPosition(column: 0, row: -1)))
        #expect(!grid.contains(GridPosition(column: 2, row: 0)))
        #expect(!grid.contains(GridPosition(column: 0, row: 3)))
    }

    @Test("safe cell(at:) returns nil outside bounds")
    func safeAccess() {
        let grid = Grid(width: 1, height: 1, repeating: 42)
        #expect(grid.cell(at: GridPosition(column: 0, row: 0)) == 42)
        #expect(grid.cell(at: GridPosition(column: 1, row: 0)) == nil)
        #expect(grid.cell(at: GridPosition(column: 0, row: 1)) == nil)
    }

    @Test("empty grid has zero extent and rejects all positions")
    func emptyGrid() {
        let grid = Grid(width: 0, height: 0, repeating: 0)
        #expect(grid.width == 0)
        #expect(grid.height == 0)
        #expect(!grid.contains(GridPosition(column: 0, row: 0)))
        #expect(grid.cell(at: GridPosition(column: 0, row: 0)) == nil)
    }

    @Test("Equatable compares dimensions and cells")
    func equatable() {
        let a = Grid(width: 2, height: 1, cells: ["a", "b"])
        let b = Grid(width: 2, height: 1, cells: ["a", "b"])
        let c = Grid(width: 2, height: 1, cells: ["a", "x"])
        #expect(a == b)
        #expect(a != c)
    }
}
