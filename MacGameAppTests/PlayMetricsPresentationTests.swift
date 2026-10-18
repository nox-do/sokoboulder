import GameCore
import Testing

@testable import MacGameApp

@Suite("Play metrics presentation")
struct PlayMetricsPresentationTests {
    @Test("Each game presents its own counters; cave time is in seconds")
    func linesDifferByMode() {
        let sokoban = PlayMetrics.sokoban(
            SokobanMetrics(
                moveCount: 12, pushCount: 3, completedGoalCount: 2, totalGoalCount: 5
            ))
        let cave = PlayMetrics.cave(
            CaveMetrics(
                collectedDiamonds: 6, requiredDiamonds: 5, remainingTicks: 900, score: 30
            ))
        #expect(PlayMetricsPresentation.lines(metrics: sokoban).map(\.value) == ["12", "3", "2/5"])
        #expect(PlayMetricsPresentation.lines(metrics: cave).map(\.value) == ["6/5", "1:30", "30"])
        #expect(PlayMetricsPresentation.caveTime(ticks: 1) == "1 s")
        #expect(PlayMetricsPresentation.caveTime(ticks: 0) == "0 s")
    }

    @Test("Outcome metrics reuse the same lines")
    func outcomeReusesLines() {
        let metrics = PlayMetrics.sokoban(
            SokobanMetrics(
                moveCount: 1, pushCount: 0, completedGoalCount: 0, totalGoalCount: 1
            ))
        let lines = PlayMetricsPresentation.outcomeMetricLines(metrics: metrics)
        #expect(lines.map(\.id) == ["moves", "pushes", "goals"])
    }

    @Test("Settings focus order is owned by SettingsFocusID")
    func settingsFocusOrder() {
        let order = SettingsFocusID.keyboardFocusOrder(
            showsThemePicker: true,
            musicTrackFocusIDs: [
                SettingsFocusID.musicTrack(for: .sokoban),
                SettingsFocusID.musicTrack(for: .cave),
            ]
        )
        #expect(order.first == SettingsFocusID.theme)
        #expect(order.contains(SettingsFocusID.musicTrack(for: .sokoban)))
        #expect(order.last == SettingsFocusID.back)
    }
}
