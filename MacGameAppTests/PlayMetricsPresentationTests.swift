import Testing
@testable import MacGameApp
import GameCore

@Suite("Play metrics presentation")
struct PlayMetricsPresentationTests {
    @Test("Sokoban and cave share one metric mapping")
    func linesDifferByMode() {
        let counters = PlayMetricCounters(
            moveCount: 12,
            pushCount: 3,
            completedGoalCount: 2,
            totalGoalCount: 5
        )
        let sokoban = PlayMetricsPresentation.lines(isCaveMode: false, counters: counters)
        #expect(sokoban.map(\.id) == ["moves", "pushes", "goals"])
        #expect(sokoban.map(\.value) == ["12", "3", "2/5"])

        let cave = PlayMetricsPresentation.lines(isCaveMode: true, counters: counters)
        #expect(cave.map(\.id) == ["diamonds", "time", "score"])
        #expect(cave.map(\.value) == ["2/5", "12", "3"])
    }

    @Test("Outcome metrics reuse the same lines")
    func outcomeReusesLines() {
        let counters = PlayMetricCounters(
            moveCount: 1,
            pushCount: 0,
            completedGoalCount: 0,
            totalGoalCount: 1
        )
        let lines = PlayMetricsPresentation.outcomeMetricLines(
            isCaveMode: false,
            counters: counters
        )
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
