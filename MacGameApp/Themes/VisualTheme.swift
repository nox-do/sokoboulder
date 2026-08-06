import CoreGraphics
import Foundation

/// Board tile-size / filtering contract. Branches over this — never hardcode theme IDs.
enum BoardRenderingProfile: String, Codable, Sendable {
    case vectorContinuous
    case pixelNearest
}

/// Optional Boulder-Dash / cave tile paths (Schema V1 additive under `textures.cave`).
struct CaveTexturePaths: Equatable, Sendable {
    var dirt: String
    var tunnel: String
    var wall: String
    var steelWall: String
    var boulder: String
    var diamond: String
    var exitClosed: String
    var exitOpen: String
    var player: String
    var firefly: String
    var butterfly: String

    var allPaths: [String] {
        [
            dirt, tunnel, wall, steelWall, boulder, diamond,
            exitClosed, exitOpen, player, firefly, butterfly,
        ]
    }
}

/// Bundle-relative texture paths for ``BoardRenderingProfile/pixelNearest``.
struct BoardTexturePaths: Equatable, Sendable {
    var floor: String
    var wall: String
    var goal: String
    var player: String
    var crate: String
    var crateOnGoal: String
    /// When present, cave mode uses these instead of procedural placeholders.
    var cave: CaveTexturePaths?

    var allPaths: [String] {
        var paths = [floor, wall, goal, player, crate, crateOnGoal]
        if let cave {
            paths.append(contentsOf: cave.allPaths)
        }
        return paths
    }
}

/// Optional rendering block on a visual theme (Schema V1 additive).
struct BoardRenderingTokens: Equatable, Sendable {
    var profile: BoardRenderingProfile
    /// Texture authoring hint (points); not used for runtime scale (ADR 0004).
    var baseTilePoints: CGFloat
    /// Legacy JSON field; ignored for scale after continuous fill (ADR 0004). `0` = unused.
    var maxIntegerScale: Int
    /// Required when ``profile`` is ``BoardRenderingProfile/pixelNearest``.
    var textures: BoardTexturePaths?

    static let vectorContinuousDefault = BoardRenderingTokens(
        profile: .vectorContinuous,
        baseTilePoints: 32,
        maxIntegerScale: 0,
        textures: nil
    )
}

/// Runtime visual theme used by board renderer, HUD, and SwiftUI overlays.
struct VisualTheme: Equatable, Sendable {
    static let standardID = "theme.standard"
    static let dungeonID = "theme.dungeon"
    static let kenneyID = "theme.kenney"
    /// Known catalog IDs (standard is code-fallback only, not Settings-listed by default).
    static let knownIDs = [standardID, dungeonID, kenneyID]
    /// Pixel themes that may be skipped on load failure without failing the catalog.
    static let optionalPixelIDs = [dungeonID, kenneyID]

    let id: String
    let displayNameID: String
    let board: BoardTokens
    let ui: UITokens
    let rendering: BoardRenderingTokens

    struct BoardTokens: Equatable, Sendable {
        var background: ThemeColor
        var terrain: TerrainTokens
        var entities: EntityTokens
        var stateMarkers: StateMarkerTokens
        var feedback: FeedbackTokens
    }

    struct TerrainTokens: Equatable, Sendable {
        var voidFill: ThemeColor
        var floorFill: ThemeColor
        var floorStroke: ThemeColor
        var wallFill: ThemeColor
        var wallStroke: ThemeColor
        var wallSymbol: String
        var goalFill: ThemeColor
        var goalStroke: ThemeColor
        var goalSymbol: String
    }

    struct EntityTokens: Equatable, Sendable {
        var playerFill: ThemeColor
        var playerStroke: ThemeColor
        var playerSymbol: String
        var crateFill: ThemeColor
        var crateStroke: ThemeColor
        var crateSymbol: String
    }

    struct StateMarkerTokens: Equatable, Sendable {
        var crateOnGoalSymbol: String
        var crateOnGoalColor: ThemeColor
        var playerOnGoalSymbol: String
        var playerOnGoalColor: ThemeColor
        var emptyGoalAccent: ThemeColor
    }

    struct FeedbackTokens: Equatable, Sendable {
        var blockedSymbol: String
        var blockedColor: ThemeColor
        var goalEnteredSymbol: String
        var goalEnteredColor: ThemeColor
        var goalLeftSymbol: String
        var goalLeftColor: ThemeColor
        var pushHighlight: ThemeColor
        var completionFrame: ThemeColor
    }

    struct UITokens: Equatable, Sendable {
        var focusRing: ThemeColor
        var focusBackground: ThemeColor
        var focusBorder: ThemeColor
        /// Text/icon color while focused. Must contrast with ``focusBackground``.
        var focusForeground: ThemeColor
        var primaryFill: ThemeColor
        var primaryForeground: ThemeColor
        var secondaryFill: ThemeColor
        var secondaryForeground: ThemeColor
        var disabledFill: ThemeColor
        var disabledForeground: ThemeColor
        var success: ThemeColor
        var warning: ThemeColor
        var error: ThemeColor
        var overlayScrim: ThemeColor
        var panelBackground: ThemeColor
        var panelForeground: ThemeColor
        var panelSecondary: ThemeColor
        var hudBackground: ThemeColor
        var hudForeground: ThemeColor
        var hudSecondary: ThemeColor
    }
}
