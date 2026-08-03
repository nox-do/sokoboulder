import Foundation

/// Development-only switch for the vector board theme.
///
/// ``theme.standard`` is not Settings-selectable; it remains the code fallback when
/// the pixel theme fails to load. Flip ``forceVectorStandard`` to compare layouts
/// while developing — no Settings UI.
@MainActor
enum DevVisualThemeSwitch {
    #if DEBUG
        /// When `true`, forces ``BuiltInThemes/standard`` (vector) regardless of catalog.
        static var forceVectorStandard = false
    #else
        static var forceVectorStandard: Bool { false }
    #endif
}
