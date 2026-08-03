import Foundation

/// Where help / settings overlays return when dismissed.
enum OverlayReturnOrigin: Equatable, Sendable {
    case gameSelection
    case launchMenu
    case paused
}
