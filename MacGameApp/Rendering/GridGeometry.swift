import CoreGraphics
import GameCore

/// Converts model grid coordinates (`(0,0)` top-left) into SpriteKit space.
///
/// The only place that knows about the vertical flip between model and scene.
///
/// Fit vs. Camera (GAMEPLAY §6.4): when the level cannot fit at ``minTilePoints``,
/// ``tileSize`` stays at the minimum and the scene pans via ``BoardCamera``.
struct GridGeometry: Equatable, Sendable {
    var availableSize: CGSize
    var gridWidth: Int
    var gridHeight: Int
    /// Profile selects vector shapes vs pixel textures / inset (ADR 0003 / 0004).
    /// Tile size itself is continuous for both profiles.
    var renderingProfile: BoardRenderingProfile = .vectorContinuous
    /// Texture authoring hint (points); also the camera ``minTilePoints`` default source.
    var baseTilePoints: CGFloat = 32
    /// Legacy field kept for theme JSON compatibility (`0` = unused).
    var maxIntegerScale: Int = 0
    /// Minimum tile edge in points before Camera mode engages (GAMEPLAY §6.4).
    var minTilePoints: CGFloat = 32

    /// Unclamped fit: largest uniform tile that shows the whole grid.
    var unconstrainedFitTileSize: CGFloat {
        guard gridWidth > 0, gridHeight > 0 else { return 0 }
        let byWidth = availableSize.width / CGFloat(gridWidth)
        let byHeight = availableSize.height / CGFloat(gridHeight)
        return min(byWidth, byHeight)
    }

    /// `true` when the board at ``minTilePoints`` (or larger) cannot fit the view.
    var usesCamera: Bool {
        guard gridWidth > 0, gridHeight > 0, minTilePoints > 0 else { return false }
        let proposed = max(unconstrainedFitTileSize, minTilePoints)
        return CGFloat(gridWidth) * proposed > availableSize.width + 0.001
            || CGFloat(gridHeight) * proposed > availableSize.height + 0.001
    }

    /// Logical tile edge length in points (uniform; letterboxed if needed).
    var tileSize: CGFloat {
        guard gridWidth > 0, gridHeight > 0 else { return 0 }
        if usesCamera {
            return minTilePoints
        }
        // Pixel themes use continuous size + `.nearest` textures (ADR 0004).
        return unconstrainedFitTileSize
    }

    /// Size of the full board in scene points (may exceed the view in Camera mode).
    var boardSize: CGSize {
        CGSize(
            width: tileSize * CGFloat(gridWidth),
            height: tileSize * CGFloat(gridHeight)
        )
    }

    /// Bottom-left of the board in board-root local space (origin at bottom-left).
    ///
    /// Fit: letterboxed inside the view. Camera: `0` on overflowing axes; letterbox
    /// on axes that still fit at ``minTilePoints``. Rounded to whole points so Retina
    /// strokes stay sharp.
    var boardOrigin: CGPoint {
        let board = boardSize
        let ox: CGFloat
        let oy: CGFloat
        if usesCamera {
            ox =
                board.width <= availableSize.width
                ? ((availableSize.width - board.width) / 2).rounded(.toNearestOrAwayFromZero)
                : 0
            oy =
                board.height <= availableSize.height
                ? ((availableSize.height - board.height) / 2).rounded(.toNearestOrAwayFromZero)
                : 0
        } else {
            ox = ((availableSize.width - board.width) / 2).rounded(.toNearestOrAwayFromZero)
            oy = ((availableSize.height - board.height) / 2).rounded(.toNearestOrAwayFromZero)
        }
        return CGPoint(x: ox, y: oy)
    }

    /// Axis-aligned board bounds in board-root local space.
    var boardBounds: CGRect {
        CGRect(origin: boardOrigin, size: boardSize)
    }

    /// Center of the cell at `position` in scene coordinates (board-root local).
    func center(for position: GridPosition) -> CGPoint {
        let x = boardOrigin.x + (CGFloat(position.column) + 0.5) * tileSize
        let y = boardOrigin.y + (CGFloat(gridHeight - 1 - position.row) + 0.5) * tileSize
        return CGPoint(x: x, y: y)
    }

    /// Frame of the cell at `position` in scene coordinates.
    func frame(for position: GridPosition) -> CGRect {
        let origin = CGPoint(
            x: boardOrigin.x + CGFloat(position.column) * tileSize,
            y: boardOrigin.y + CGFloat(gridHeight - 1 - position.row) * tileSize
        )
        return CGRect(origin: origin, size: CGSize(width: tileSize, height: tileSize))
    }
}
