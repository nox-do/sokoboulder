import Foundation

/// Why a theme document or catalog cannot be used.
enum ThemeDecodeError: Error, Equatable, Sendable {
    case notAnObject
    case unknownKeys([String])
    case missingKeys([String])
    case unsupportedSchemaVersion(Int)
    case emptyID
    case emptyDisplayNameID
    case invalidColor(String)
    case duplicateThemeID(String)
    case emptyThemePath
    case duplicateThemePath(String)
    case missingTheme(id: String)
}
