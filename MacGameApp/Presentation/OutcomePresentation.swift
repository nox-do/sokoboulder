import Foundation

/// One game-neutral metric on the shared outcome overlay.
struct OutcomeMetricLine: Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    /// Presentation-ready value, e.g. `"12"`, `"3/4"`, or `"01:30"`.
    var value: String
}

/// One best-score line on the shared outcome overlay.
struct OutcomeRecordLine: Equatable, Sendable {
    var title: String
    /// Presentation-ready so each game owns score/time formatting.
    var value: String
    var isNewRecord: Bool
    var newRecordTitle: String
}

/// Data-only model for the shared outcome / result overlay.
struct OutcomePresentation: Equatable, Sendable {
    var title: String
    var metrics: [OutcomeMetricLine]
    var records: [OutcomeRecordLine]
    var hint: String
    var primaryTitle: String
    var playAgainTitle: String
    var playAgainEnabled: Bool
    var undoTitle: String
    var undoEnabled: Bool
    var levelSelectTitle: String
}
