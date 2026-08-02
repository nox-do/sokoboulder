import Foundation

/// One row in the shared help / controls overview.
struct HelpControlRow: Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    var detail: String
}

/// One tutorial hint that remains reachable from help even after intro was seen.
struct HelpTutorialHint: Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    var body: String
}

/// Data-only model for the shared help overlay.
struct HelpPresentation: Equatable, Sendable {
    var title: String
    var backTitle: String
    var controls: [HelpControlRow]
    var tutorialSectionTitle: String
    var tutorialHints: [HelpTutorialHint]
}
