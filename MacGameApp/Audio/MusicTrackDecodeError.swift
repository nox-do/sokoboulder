import Foundation

/// Why a music-track document or catalog cannot be used.
enum MusicTrackDecodeError: Error, Equatable, Sendable {
    case notAnObject
    case unknownKeys([String])
    case missingKeys([String])
    case unsupportedSchemaVersion(Int)
    case emptyID
    case emptyTrackPath
    case duplicateTrackID(String)
    case missingTrack(id: String)
    case invalidGame(String)
    case emptyResourcePath(field: String)
    case emptyCreditField(String)
}
