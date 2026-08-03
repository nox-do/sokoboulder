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
            ),
            rendering: .vectorContinuousDefault
        )
    }

    static func allFallbacks() -> [VisualTheme] {
        [standard]
    }

    private static func color(_ hex: String) -> ThemeColor {
        // Built-ins are authored; failure would be a programmer error.
        try! ThemeColor.parse(hex)
    }
}
