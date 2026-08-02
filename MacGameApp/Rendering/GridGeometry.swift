import CoreGraphics
import GameCore

/// Converts model grid coordinates (`(0,0)` top-left) into SpriteKit space.
///
/// The only place that knows about the vertical flip between model and scene.
struct GridGeometry: Equatable, Sendable {
    var availableSize: CGSize
    var gridWidth: Int
    var gridHeight: Int

    /// Logical tile edge length in points (uniform; letterboxed if needed).
    var tileSize: CGFloat {
        guard gridWidth > 0, gridHeight > 0 else { return 0 }
        let byWidth = availableSize.width / CGFloat(gridWidth)
        let byHeight = availableSize.height / CGFloat(gridHeight)
        return min(byWidth, byHeight)
    }

    /// Size of the letterboxed board in scene points.
    var boardSize: CGSize {
        CGSize(
            width: tileSize * CGFloat(gridWidth),
            height: tileSize * CGFloat(gridHeight)
        )
    }

    /// Bottom-left of the centered board in the available area (origin at bottom-left).
    /// Rounded to whole points so Retina strokes stay sharp.
    var boardOrigin: CGPoint {
        CGPoint(
            x: ((availableSize.width - boardSize.width) / 2).rounded(.toNearestOrAwayFromZero),
            y: ((availableSize.height - boardSize.height) / 2).rounded(.toNearestOrAwayFromZero)
        )
    }

    /// Center of the cell at `position` in scene coordinates.
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
