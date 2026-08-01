import Foundation

/// Which result-overlay button currently owns keyboard focus.
///
/// Return/Space confirms this action via ``GameplayInputRouter`` (no SwiftUI
/// `.defaultAction`), so Tab focus and confirm stay aligned.
enum OutcomeFocusedAction: Equatable, Sendable {
    case primary
    case again
    case undo
}
