import Foundation

/// Launch-menu selection owned by ``SokobanPlayController``.
enum LaunchMenuAction: String, CaseIterable, Equatable, Sendable {
    case continueCampaign
    case selectLevel
    case help
    case settings
    case resetProgress
}

/// Pause-menu selection owned by ``SokobanPlayController``.
enum PauseMenuAction: String, CaseIterable, Equatable, Sendable {
    case resume
    case restart
    case settings
    case levelSelection
    case help
}
