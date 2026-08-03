import Foundation

/// Top-level game picker selection owned by ``SokobanPlayController``.
enum GameSelectionAction: String, CaseIterable, Equatable, Sendable {
    case sokoban
    case cave
    case help
    case settings

    static var focusOrder: [GameSelectionAction] { [.sokoban, .cave, .help, .settings] }

    var isEnabled: Bool {
        switch self {
        case .sokoban, .cave, .help, .settings: true
        }
    }
}

/// Sokoban hub selection owned by ``SokobanPlayController``.
enum LaunchMenuAction: String, CaseIterable, Equatable, Sendable {
    case continueCampaign
    case selectLevel
    case help
    case settings
    case resetProgress
    case backToGameSelection
}

/// Pause-menu selection owned by ``SokobanPlayController``.
enum PauseMenuAction: String, CaseIterable, Equatable, Sendable {
    case resume
    case restart
    case settings
    case levelSelection
    case help
}
