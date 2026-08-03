import CoreGraphics
import GameCore

/// Converts model grid coordinates (`(0,0)` top-left) into SpriteKit space.
///
/// The only place that knows about the vertical flip between model and scene.
struct GridGeometry: Equatable, Sendable {
    var availableSize: CGSize
    var gridWidth: Int
    var gridHeight: Int
    /// Profile selects vector shapes vs pixel textures / inset (ADR 0003 / 0004).
    /// Tile size itself is continuous for both profiles.
    var renderingProfile: BoardRenderingProfile = .vectorContinuous
    /// Texture authoring hint (points); not used for runtime scale.
    var baseTilePoints: CGFloat = 32
    /// Legacy field kept for theme JSON compatibility (`0` = unused).
    var maxIntegerScale: Int = 0

    /// Logical tile edge length in points (uniform; letterboxed if needed).
    var tileSize: CGFloat {
        guard gridWidth > 0, gridHeight > 0 else { return 0 }
        let byWidth = availableSize.width / CGFloat(gridWidth)
        let byHeight = availableSize.height / CGFloat(gridHeight)
        // Pixel themes use continuous size + `.nearest` textures (ADR 0004).
        // Integer stepping left large letterbox between 32‑pt multiples.
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
