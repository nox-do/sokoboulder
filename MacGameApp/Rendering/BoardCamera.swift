import CoreGraphics
import Foundation
import GameCore

/// Presentation-only camera focus for large boards (GAMEPLAY §6.4).
///
/// Operates in board-root local space. The scene applies ``boardRootPosition(focus:viewSize:)``
/// so ``focus`` appears at the view center.
struct BoardCamera: Equatable, Sendable {
    /// Inner safe-zone fraction of the viewport (60 % → 20 % margin per side).
    static let safeZoneFraction: CGFloat = 0.60
    /// Look-ahead distance in tiles along the last move direction.
    static let lookAheadTiles: CGFloat = 0.75
    /// Soft follow time constant (~150 ms to settle).
    static let followDuration: TimeInterval = 0.15

    /// Current focus point (view center in board-root space).
    var focus: CGPoint = .zero
    /// Last player move used for look-ahead; cleared when unknown.
    var lastMoveDirection: Direction?

    /// Clamped focus that keeps the visible rect inside ``boardBounds`` when possible.
    static func clampFocus(
        _ focus: CGPoint,
        boardBounds: CGRect,
        viewSize: CGSize
    ) -> CGPoint {
        var x = focus.x
        var y = focus.y

        if boardBounds.width <= viewSize.width {
            x = boardBounds.midX
        } else {
            let half = viewSize.width / 2
            let minX = boardBounds.minX + half
            let maxX = boardBounds.maxX - half
            x = min(max(x, minX), maxX)
        }

        if boardBounds.height <= viewSize.height {
            y = boardBounds.midY
        } else {
            let half = viewSize.height / 2
            let minY = boardBounds.minY + half
            let maxY = boardBounds.maxY - half
            y = min(max(y, minY), maxY)
        }

        return CGPoint(x: x, y: y)
    }

    /// Desired focus from player position, current focus (safe zone), and optional look-ahead.
    static func desiredFocus(
        playerCenter: CGPoint,
        currentFocus: CGPoint,
        viewSize: CGSize,
        boardBounds: CGRect,
        tileSize: CGFloat,
        lookAheadDirection: Direction?,
        lookAheadEnabled: Bool
    ) -> CGPoint {
        let marginFraction = (1 - safeZoneFraction) / 2  // 0.20 when fraction is 0.60
        let safeHalfWidth = viewSize.width * (0.5 - marginFraction)  // 0.30 * W
        let safeHalfHeight = viewSize.height * (0.5 - marginFraction)

        var focus = currentFocus

        let safeMinX = currentFocus.x - safeHalfWidth
        let safeMaxX = currentFocus.x + safeHalfWidth
        if playerCenter.x < safeMinX {
            focus.x = playerCenter.x + safeHalfWidth
        } else if playerCenter.x > safeMaxX {
            focus.x = playerCenter.x - safeHalfWidth
        }

        let safeMinY = currentFocus.y - safeHalfHeight
        let safeMaxY = currentFocus.y + safeHalfHeight
        if playerCenter.y < safeMinY {
            focus.y = playerCenter.y + safeHalfHeight
        } else if playerCenter.y > safeMaxY {
            focus.y = playerCenter.y - safeHalfHeight
        }

        if lookAheadEnabled, let direction = lookAheadDirection, tileSize > 0 {
            let distance = lookAheadTiles * tileSize
            switch direction {
            case .up: focus.y += distance
            case .down: focus.y -= distance
            case .left: focus.x -= distance
            case .right: focus.x += distance
            }
        }

        return clampFocus(focus, boardBounds: boardBounds, viewSize: viewSize)
    }

    /// Initial / snap focus: player centered, then clamped (no safe-zone hysteresis).
    static func snapFocus(
        playerCenter: CGPoint,
        viewSize: CGSize,
        boardBounds: CGRect,
        tileSize: CGFloat,
        lookAheadDirection: Direction?,
        lookAheadEnabled: Bool
    ) -> CGPoint {
        var focus = playerCenter
        if lookAheadEnabled, let direction = lookAheadDirection, tileSize > 0 {
            let distance = lookAheadTiles * tileSize
            switch direction {
            case .up: focus.y += distance
            case .down: focus.y -= distance
            case .left: focus.x -= distance
            case .right: focus.x += distance
            }
        }
        return clampFocus(focus, boardBounds: boardBounds, viewSize: viewSize)
    }

    /// ``boardRoot.position`` so ``focus`` sits at the view center.
    static func boardRootPosition(focus: CGPoint, viewSize: CGSize) -> CGPoint {
        CGPoint(
            x: viewSize.width / 2 - focus.x,
            y: viewSize.height / 2 - focus.y
        )
    }

    /// Exponential approach toward `target` with ``followDuration``.
    static func stepFocus(
        from current: CGPoint,
        toward target: CGPoint,
        deltaTime: TimeInterval
    ) -> CGPoint {
        guard deltaTime > 0 else { return current }
        let duration = followDuration
        guard duration > 0 else { return target }
        let t = CGFloat(1 - exp(-deltaTime / duration))
        return CGPoint(
            x: current.x + (target.x - current.x) * t,
            y: current.y + (target.y - current.y) * t
        )
    }

    /// Infers player move direction from render events (last player ``entityMoved`` wins).
    static func playerMoveDirection(from events: [GameEvent]) -> Direction? {
        var found: Direction?
        for event in events {
            guard case .entityMoved(let ref, let from, let to) = event, ref.kind == .player else {
                continue
            }
            let dc = to.column - from.column
            let dr = to.row - from.row
            if dc == 1, dr == 0 { found = .right }
            else if dc == -1, dr == 0 { found = .left }
            else if dc == 0, dr == 1 { found = .down }
            else if dc == 0, dr == -1 { found = .up }
        }
        return found
    }

    mutating func snap(
        toPlayerCenter playerCenter: CGPoint,
        geometry: GridGeometry,
        lookAheadEnabled: Bool
    ) {
        focus = Self.snapFocus(
            playerCenter: playerCenter,
            viewSize: geometry.availableSize,
            boardBounds: geometry.boardBounds,
            tileSize: geometry.tileSize,
            lookAheadDirection: lastMoveDirection,
            lookAheadEnabled: lookAheadEnabled
        )
    }

    mutating func reset() {
        focus = .zero
        lastMoveDirection = nil
    }
}
