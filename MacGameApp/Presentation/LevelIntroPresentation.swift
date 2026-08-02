import Foundation

/// Data-only model for the shared level-intro overlay (no game-rule logic).
struct LevelIntroPresentation: Equatable, Sendable {
    var title: String
    var body: String
    var continueTitle: String
    var skipHint: String
    /// When non-nil, auto-dismiss after this delay unless assistive reading blocks it.
    var autoDismissDelay: TimeInterval?
}
