import CoreGraphics
import Testing
@testable import GameCore
@testable import MacGameApp

@Suite("GridGeometry")
struct GridGeometryTests {
    @Test("centers flip model Y and letterbox inside the available area")
    func centersAndLetterbox() {
        var geometry = GridGeometry(
            availableSize: CGSize(width: 300, height: 200),
            gridWidth: 3,
            gridHeight: 2
        )
        // tile = min(100, 100) = 100; board 300×200 fills width fully.
        #expect(geometry.tileSize == 100)
        #expect(geometry.boardOrigin.x == 0)
        #expect(geometry.boardOrigin.y == 0)

        let topLeft = geometry.center(for: GridPosition(column: 0, row: 0))
        #expect(topLeft.x == 50)
        #expect(topLeft.y == 150)

        let bottomRight = geometry.center(for: GridPosition(column: 2, row: 1))
        #expect(bottomRight.x == 250)
        #expect(bottomRight.y == 50)
    }

    @Test("narrow window letterboxes horizontally")
    func horizontalLetterbox() {
        let geometry = GridGeometry(
            availableSize: CGSize(width: 100, height: 200),
            gridWidth: 2,
            gridHeight: 2
        )
        #expect(geometry.tileSize == 50)
        #expect(geometry.boardOrigin.x == 0)
        #expect(geometry.boardOrigin.y == 50)
    }
}
