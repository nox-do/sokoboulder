import Foundation
import GameCore

/// One labeled metric row for HUD (and shared titles/values elsewhere).
struct PlayMetricLine: Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    var value: String
}

/// Shared formatting for HUD, outcome, intro and accessibility.
enum PlayMetricsPresentation {
    static func caveTime(ticks: Int) -> String {
        let seconds = Int(ceil(Double(ticks) * CaveRules.fixedStepSeconds))
        if seconds < 60 { return "\(seconds) s" }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    static func lines(metrics: PlayMetrics) -> [PlayMetricLine] {
        switch metrics {
        case .cave(let cave):
            return [
                PlayMetricLine(
                    id: "diamonds", title: AppStrings.text(.uiHudDiamonds),
                    value: "\(cave.collectedDiamonds)/\(cave.requiredDiamonds)"
                ),
                PlayMetricLine(
                    id: "time", title: AppStrings.text(.uiHudTime),
                    value: caveTime(ticks: cave.remainingTicks)
                ),
                PlayMetricLine(id: "score", title: AppStrings.text(.uiHudScore), value: String(cave.score)),
            ]
        case .sokoban(let sokoban):
            return [
                PlayMetricLine(id: "moves", title: AppStrings.text(.uiHudMoves), value: String(sokoban.moveCount)),
                PlayMetricLine(id: "pushes", title: AppStrings.text(.uiHudPushes), value: String(sokoban.pushCount)),
                PlayMetricLine(
                    id: "goals", title: AppStrings.text(.uiHudGoals),
                    value: "\(sokoban.completedGoalCount)/\(sokoban.totalGoalCount)"
                ),
            ]
        }
    }

    static func outcomeMetricLines(metrics: PlayMetrics) -> [OutcomeMetricLine] {
        lines(metrics: metrics).map { OutcomeMetricLine(id: $0.id, title: $0.title, value: $0.value) }
    }

    static func accessibilityMetrics(metrics: PlayMetrics) -> String {
        lines(metrics: metrics).map { "\($0.title) \($0.value.replacingOccurrences(of: "/", with: " von "))" }
            .joined(separator: ". ") + "."
    }
}
