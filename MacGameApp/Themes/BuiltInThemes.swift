import Foundation

/// Built-in themes used when JSON is missing or incomplete.
enum BuiltInThemes {
    static var standard: VisualTheme {
        VisualTheme(
            id: VisualTheme.standardID,
            displayNameID: "theme.standard.name",
            board: .init(
                background: color("#1E1E1E"),
                terrain: .init(
                    voidFill: color("#0A0A0A"),
                    floorFill: color("#38473D"),
                    floorStroke: color("#4A5C50"),
                    wallFill: color("#736659"),
                    wallStroke: color("#E8E0D8"),
                    wallSymbol: "▦",
                    goalFill: color("#2F6F86"),
                    goalStroke: color("#D8F0F8"),
                    goalSymbol: "◎"
                ),
                entities: .init(
                    playerFill: color("#F2BF33"),
                    playerStroke: color("#FFF4C8"),
                    playerSymbol: "◆",
                    crateFill: color("#C45A2C"),
                    crateStroke: color("#FFE0C8"),
                    crateSymbol: "■"
                ),
                stateMarkers: .init(
                    crateOnGoalSymbol: "✓",
                    crateOnGoalColor: color("#FFFFFF"),
                    playerOnGoalSymbol: "✓",
                    playerOnGoalColor: color("#FFFFFF"),
                    emptyGoalAccent: color("#9ED7E8")
                ),
                feedback: .init(
                    blockedSymbol: "×",
                    blockedColor: color("#FF5A5A"),
                    goalEnteredSymbol: "✓",
                    goalEnteredColor: color("#55E08A"),
                    goalLeftSymbol: "↶",
                    goalLeftColor: color("#FFB04A"),
                    pushHighlight: color("#FFFFFF"),
                    completionFrame: color("#55E08A")
                )
            ),
            ui: .init(
                focusRing: color("#5CB0FF"),
                focusBackground: color("#1A3A5C"),
                focusBorder: color("#8AC8FF"),
                focusForeground: color("#FFFFFF"),
                primaryFill: color("#3A7BD5"),
                primaryForeground: color("#FFFFFF"),
                secondaryFill: color("#3A3A3A"),
                secondaryForeground: color("#EEEEEE"),
                disabledFill: color("#2A2A2A"),
                disabledForeground: color("#777777"),
                success: color("#3DDC84"),
                warning: color("#F5A623"),
                error: color("#E74C3C"),
                overlayScrim: color("#00000073"),
                panelBackground: color("#2A2A2AF2"),
                panelForeground: color("#F2F2F2"),
                panelSecondary: color("#B0B0B0"),
                hudBackground: color("#1A1A1ACC"),
                hudForeground: color("#F0F0F0"),
                hudSecondary: color("#A8A8A8")
            )
        )
    }

    /// Independently authored high-contrast palette (not derived from standard).
    static var highContrast: VisualTheme {
        VisualTheme(
            id: VisualTheme.highContrastID,
            displayNameID: "theme.highContrast.name",
            board: .init(
                background: color("#000000"),
                terrain: .init(
                    voidFill: color("#000000"),
                    floorFill: color("#FFFFFF"),
                    floorStroke: color("#000000"),
                    wallFill: color("#000000"),
                    wallStroke: color("#FFFFFF"),
                    wallSymbol: "▦",
                    goalFill: color("#FFFF00"),
                    goalStroke: color("#000000"),
                    goalSymbol: "◎"
                ),
                entities: .init(
                    playerFill: color("#00FFFF"),
                    playerStroke: color("#000000"),
                    playerSymbol: "◆",
                    crateFill: color("#FF00FF"),
                    crateStroke: color("#000000"),
                    crateSymbol: "■"
                ),
                stateMarkers: .init(
                    crateOnGoalSymbol: "✓",
                    crateOnGoalColor: color("#000000"),
                    playerOnGoalSymbol: "✓",
                    playerOnGoalColor: color("#000000"),
                    emptyGoalAccent: color("#000000")
                ),
                feedback: .init(
                    blockedSymbol: "×",
                    blockedColor: color("#FF0000"),
                    goalEnteredSymbol: "✓",
                    goalEnteredColor: color("#008000"),
                    goalLeftSymbol: "↶",
                    goalLeftColor: color("#FF8000"),
                    pushHighlight: color("#FFFFFF"),
                    completionFrame: color("#00FF00")
                )
            ),
            ui: .init(
                focusRing: color("#FFFF00"),
                focusBackground: color("#000000"),
                focusBorder: color("#FFFF00"),
                focusForeground: color("#FFFF00"),
                primaryFill: color("#FFFF00"),
                primaryForeground: color("#000000"),
                secondaryFill: color("#FFFFFF"),
                secondaryForeground: color("#000000"),
                disabledFill: color("#666666"),
                disabledForeground: color("#FFFFFF"),
                success: color("#00FF00"),
                warning: color("#FF8000"),
                error: color("#FF0000"),
                overlayScrim: color("#000000CC"),
                panelBackground: color("#000000"),
                panelForeground: color("#FFFFFF"),
                panelSecondary: color("#FFFF00"),
                hudBackground: color("#000000"),
                hudForeground: color("#FFFFFF"),
                hudSecondary: color("#FFFF00")
            )
        )
    }

    static func fallback(id: String) -> VisualTheme {
        switch id {
        case VisualTheme.highContrastID:
            return highContrast
        default:
            return standard
        }
    }

    static func allFallbacks() -> [VisualTheme] {
        [standard, highContrast]
    }

    private static func color(_ hex: String) -> ThemeColor {
        // Built-ins are authored; failure would be a programmer error.
        try! ThemeColor.parse(hex)
    }
}
