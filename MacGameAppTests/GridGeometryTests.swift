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

    @Test("pixelInteger fills continuously like vector (nearest textures)")
    func pixelIntegerFillsContinuously() {
        // continuous = min(200/5, 160/4) = 40 — no integer step-down to 32
        let geometry = GridGeometry(
            availableSize: CGSize(width: 200, height: 160),
            gridWidth: 5,
            gridHeight: 4,
            renderingProfile: .pixelInteger,
            baseTilePoints: 32
        )
        #expect(geometry.tileSize == 40)
        #expect(geometry.boardSize.width == 200)
        #expect(geometry.boardSize.height == 160)
        #expect(geometry.boardOrigin.x == geometry.boardOrigin.x.rounded())
        #expect(geometry.boardOrigin.y == geometry.boardOrigin.y.rounded())
    }

    @Test("pixelInteger letterboxes only the leftover aspect ratio")
    func pixelIntegerAspectLetterbox() {
        // continuous = min(640/5, 480/3) = min(128, 160) = 128
        let geometry = GridGeometry(
            availableSize: CGSize(width: 640, height: 480),
            gridWidth: 5,
            gridHeight: 3,
            renderingProfile: .pixelInteger,
            baseTilePoints: 32,
            maxIntegerScale: 0
        )
        #expect(geometry.tileSize == 128)
        #expect(geometry.boardSize.width == 640)
        #expect(geometry.boardSize.height == 384)
    }

    @Test("pixelInteger ignores maxIntegerScale after continuous fill")
    func pixelIntegerIgnoresLegacyCap() {
        let geometry = GridGeometry(
            availableSize: CGSize(width: 640, height: 480),
            gridWidth: 5,
            gridHeight: 3,
            renderingProfile: .pixelInteger,
            baseTilePoints: 32,
            maxIntegerScale: 2
        )
        #expect(geometry.tileSize == 128)
    }

    @Test("vectorContinuous ignores baseTilePoints")
    func vectorIgnoresBaseTilePoints() {
        let geometry = GridGeometry(
            availableSize: CGSize(width: 200, height: 160),
            gridWidth: 5,
            gridHeight: 4,
            renderingProfile: .vectorContinuous,
            baseTilePoints: 32
        )
        #expect(geometry.tileSize == 40)
    }
}
