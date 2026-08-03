import Foundation

/// Why an audio theme document or catalog cannot be used.
enum AudioThemeDecodeError: Error, Equatable, Sendable {
    case notAnObject
    case unknownKeys([String])
    case missingKeys([String])
    case unsupportedSchemaVersion(Int)
    case emptyID
    case emptyThemePath
    case duplicateThemeID(String)
    case duplicateThemePath(String)
    case duplicateGame(AudioGameMode)
    case missingTheme(id: String)
    case invalidGame(String)
    case invalidCueKey(String)
    case emptyResourcePath(field: String)
}
