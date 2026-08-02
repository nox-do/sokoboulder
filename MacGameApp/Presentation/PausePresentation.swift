import Foundation

/// Data-only model for the shared pause overlay.
struct PausePresentation: Equatable, Sendable {
    var title: String
    var hint: String
    var resumeTitle: String
    var restartTitle: String
    var settingsTitle: String
    var levelSelectTitle: String
    var helpTitle: String
}
