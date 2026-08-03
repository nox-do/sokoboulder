import Foundation
import GameCore

/// Shared play counters projected for HUD / outcome / accessibility.
struct PlayMetricCounters: Equatable, Sendable {
    var moveCount: Int
    var pushCount: Int
    var completedGoalCount: Int
    var totalGoalCount: Int

    init(
        moveCount: Int,
        pushCount: Int,
        completedGoalCount: Int,
        totalGoalCount: Int
    ) {
        self.moveCount = moveCount
        self.pushCount = pushCount
        self.completedGoalCount = completedGoalCount
        self.totalGoalCount = totalGoalCount
    }

    init(snapshot: RenderSnapshot) {
        self.moveCount = snapshot.moveCount
        self.pushCount = snapshot.pushCount
        self.completedGoalCount = snapshot.completedGoalCount
        self.totalGoalCount = snapshot.totalGoalCount
    }
}

/// One labeled metric row for HUD (and shared titles/values elsewhere).
struct PlayMetricLine: Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    var value: String
}

/// Single source for cave vs Sokoban metric labels and value formatting.
enum PlayMetricsPresentation {
    static func lines(isCaveMode: Bool, counters: PlayMetricCounters) -> [PlayMetricLine] {
        if isCaveMode {
            return [
                PlayMetricLine(
                    id: "diamonds",
                    title: AppStrings.text(.uiHudDiamonds),
                    value: "\(counters.completedGoalCount)/\(counters.totalGoalCount)"
                ),
                PlayMetricLine(
                    id: "time",
                    title: AppStrings.text(.uiHudTime),
                    value: String(counters.moveCount)
                ),
                PlayMetricLine(
                    id: "score",
                    title: AppStrings.text(.uiHudScore),
                    value: String(counters.pushCount)
                ),
            ]
        }
        return [
            PlayMetricLine(
                id: "moves",
                title: AppStrings.text(.uiHudMoves),
                value: String(counters.moveCount)
            ),
            PlayMetricLine(
                id: "pushes",
                title: AppStrings.text(.uiHudPushes),
                value: String(counters.pushCount)
            ),
            PlayMetricLine(
                id: "goals",
                title: AppStrings.text(.uiHudGoals),
                value: "\(counters.completedGoalCount)/\(counters.totalGoalCount)"
            ),
        ]
    }

    static func outcomeMetricLines(
        isCaveMode: Bool,
        counters: PlayMetricCounters
    ) -> [OutcomeMetricLine] {
        lines(isCaveMode: isCaveMode, counters: counters).map {
            OutcomeMetricLine(id: $0.id, title: $0.title, value: $0.value)
        }
    }

    /// Spoken metric suffix after player position (German "von" kept for a11y parity).
    static func accessibilityMetrics(
        isCaveMode: Bool,
        counters: PlayMetricCounters
    ) -> String {
        if isCaveMode {
            return "\(AppStrings.text(.uiHudDiamonds)) "
                + "\(counters.completedGoalCount) von \(counters.totalGoalCount). "
                + "\(AppStrings.text(.uiHudTime)) \(counters.moveCount), "
                + "\(AppStrings.text(.uiHudScore)) \(counters.pushCount)."
        }
        return "\(AppStrings.text(.uiHudGoals)) "
            + "\(counters.completedGoalCount) von \(counters.totalGoalCount). "
            + "\(AppStrings.text(.uiHudMoves)) \(counters.moveCount), "
            + "\(AppStrings.text(.uiHudPushes)) \(counters.pushCount)."
    }
}
