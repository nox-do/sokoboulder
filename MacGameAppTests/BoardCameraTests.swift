import CoreGraphics
import Testing
@testable import GameCore
@testable import MacGameApp

@Suite("BoardCamera")
struct BoardCameraTests {
    @Test("clamp keeps focus inside a larger board")
    func clampInsideLargeBoard() {
        let bounds = CGRect(x: 0, y: 0, width: 640, height: 448)
        let view = CGSize(width: 320, height: 240)
        let clamped = BoardCamera.clampFocus(
            CGPoint(x: 0, y: 0),
            boardBounds: bounds,
            viewSize: view
        )
        #expect(clamped.x == 160 as CGFloat)
        #expect(clamped.y == 120 as CGFloat)

        let far = BoardCamera.clampFocus(
            CGPoint(x: 9999, y: 9999),
            boardBounds: bounds,
            viewSize: view
        )
        #expect(far.x == 480 as CGFloat)
        #expect(far.y == 328 as CGFloat)
    }

    @Test("clamp centers when the board fits on an axis")
    func clampCentersWhenBoardFits() {
        let bounds = CGRect(x: 40, y: 20, width: 200, height: 400)
        let view = CGSize(width: 320, height: 240)
        let focus = BoardCamera.clampFocus(
            CGPoint(x: 0, y: 300),
            boardBounds: bounds,
            viewSize: view
        )
        #expect(focus.x == bounds.midX)
        #expect(focus.y == 300 as CGFloat)
        let yClamped = BoardCamera.clampFocus(
            CGPoint(x: 140, y: 0),
            boardBounds: bounds,
            viewSize: view
        )
        #expect(yClamped.y == 140 as CGFloat)
    }

    @Test("safe zone leaves focus unchanged while player stays inside")
    func safeZoneIdle() {
        let view = CGSize(width: 400, height: 300)
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let focus = CGPoint(x: 200, y: 150)
        let desired = BoardCamera.desiredFocus(
            playerCenter: CGPoint(x: 220, y: 160),
            currentFocus: focus,
            viewSize: view,
            boardBounds: bounds,
            tileSize: 32,
            lookAheadDirection: nil,
            lookAheadEnabled: false
        )
        #expect(desired == focus)
    }

    @Test("leaving the safe zone pulls focus to the inner edge")
    func safeZonePull() {
        let view = CGSize(width: 400, height: 300)
        let bounds = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        let focus = CGPoint(x: 400, y: 400)
        let desired = BoardCamera.desiredFocus(
            playerCenter: CGPoint(x: 600, y: 400),
            currentFocus: focus,
            viewSize: view,
            boardBounds: bounds,
            tileSize: 32,
            lookAheadDirection: nil,
            lookAheadEnabled: false
        )
        #expect(desired.x == 480 as CGFloat)
        #expect(desired.y == 400 as CGFloat)
    }

    @Test("look-ahead offsets focus then clamps")
    func lookAhead() {
        let view = CGSize(width: 400, height: 300)
        let bounds = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        let focus = CGPoint(x: 400, y: 400)
        let desired = BoardCamera.desiredFocus(
            playerCenter: CGPoint(x: 400, y: 400),
            currentFocus: focus,
            viewSize: view,
            boardBounds: bounds,
            tileSize: 32,
            lookAheadDirection: .right,
            lookAheadEnabled: true
        )
        #expect(desired.x == 400 + 0.75 * 32)
        #expect(desired.y == 400 as CGFloat)
    }

    @Test("player move direction from entityMoved events")
    func moveDirectionFromEvents() {
        let player = EntityRef(id: EntityID(1), kind: .player)
        let events: [GameEvent] = [
            .entityMoved(player, from: GridPosition(column: 2, row: 3), to: GridPosition(column: 3, row: 3))
        ]
        #expect(BoardCamera.playerMoveDirection(from: events) == .right)
    }

    @Test("board root position centers focus in the view")
    func boardRootCentersFocus() {
        let position = BoardCamera.boardRootPosition(
            focus: CGPoint(x: 100, y: 80),
            viewSize: CGSize(width: 320, height: 240)
        )
        #expect(position.x == 60 as CGFloat)
        #expect(position.y == 40 as CGFloat)
    }
}

@Suite("GridGeometry camera mode")
struct GridGeometryCameraTests {
    @Test("small boards stay in Fit with continuous tile size")
    func smallBoardFits() {
        let geometry = GridGeometry(
            availableSize: CGSize(width: 320, height: 240),
            gridWidth: 5,
            gridHeight: 4,
            minTilePoints: 32
        )
        #expect(!geometry.usesCamera)
        #expect(geometry.tileSize == 60 as CGFloat)
    }

    @Test("large boards engage Camera at minTile")
    func largeBoardUsesCamera() {
        let geometry = GridGeometry(
            availableSize: CGSize(width: 320, height: 240),
            gridWidth: 40,
            gridHeight: 30,
            minTilePoints: 32
        )
        #expect(geometry.usesCamera)
        #expect(geometry.tileSize == 32 as CGFloat)
        #expect(geometry.boardSize.width == 1280 as CGFloat)
        #expect(geometry.boardSize.height == 960 as CGFloat)
        #expect(geometry.boardOrigin == .zero)
    }

    @Test("camera letterboxes the axis that still fits")
    func cameraLetterboxesFittingAxis() {
        // 20×5 at 32pt = 640×160; view 320×240 → width overflows, height fits
        let geometry = GridGeometry(
            availableSize: CGSize(width: 320, height: 240),
            gridWidth: 20,
            gridHeight: 5,
            minTilePoints: 32
        )
        #expect(geometry.usesCamera)
        #expect(geometry.boardOrigin.x == 0 as CGFloat)
        #expect(geometry.boardOrigin.y == 40 as CGFloat)
    }
}
