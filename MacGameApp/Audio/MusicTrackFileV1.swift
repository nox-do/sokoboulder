import Foundation

/// Music track catalog index (schema V1).
struct MusicTrackManifestV1: Equatable, Codable, Sendable {
    static let currentSchemaVersion = 1
    static let resourcePath = "Audio/Music/tracks.json"

    let schemaVersion: Int
    let defaultTrackID: String
    let tracks: [MusicTrackFileEntryV1]
}

struct MusicTrackFileEntryV1: Equatable, Codable, Sendable {
    let id: String
    let game: String
    let displayNameID: String
    let resourcePath: String
    let credit: MusicTrackCreditFileV1
}

struct MusicTrackCreditFileV1: Equatable, Codable, Sendable {
    let title: String
    let author: String
    let sourceURL: String
    let license: String
    let attributionNotice: String?
}

enum StrictMusicTrackJSON {
    private static let rootAllowed: Set<String> = [
        "schemaVersion", "defaultTrackID", "tracks",
    ]
    private static let rootRequired = rootAllowed

    private static let trackAllowed: Set<String> = [
        "id", "game", "displayNameID", "resourcePath", "credit",
    ]
    private static let trackRequired = trackAllowed

    private static let creditAllowed: Set<String> = [
        "title", "author", "sourceURL", "license", "attributionNotice",
    ]
    private static let creditRequired: Set<String> = [
        "title", "author", "sourceURL", "license",
    ]

    static func validateKeys(_ data: Data) throws {
        let root = try jsonObject(data)
        try validateObjectKeys(root, allowed: rootAllowed, required: rootRequired)

        guard let tracks = root["tracks"] as? [Any] else {
            throw MusicTrackDecodeError.missingKeys(["tracks"])
        }
        for (index, entry) in tracks.enumerated() {
            guard let track = entry as? [String: Any] else {
                throw MusicTrackDecodeError.notAnObject
            }
            try validateObjectKeys(
                track,
                allowed: trackAllowed,
                required: trackRequired,
                prefix: "tracks[\(index)]"
            )
            guard let credit = track["credit"] as? [String: Any] else {
                throw MusicTrackDecodeError.missingKeys(["tracks[\(index)].credit"])
            }
            try validateObjectKeys(
                credit,
                allowed: creditAllowed,
                required: creditRequired,
                prefix: "tracks[\(index)].credit"
            )
        }
    }

    private static func validateObjectKeys(
        _ object: [String: Any],
        allowed: Set<String>,
        required: Set<String>,
        prefix: String? = nil
    ) throws {
        let keys = Set(object.keys)
        let unknown = keys.subtracting(allowed).sorted()
        guard unknown.isEmpty else {
            let labeled = unknown.map { key in prefix.map { "\($0).\(key)" } ?? key }
            throw MusicTrackDecodeError.unknownKeys(labeled)
        }
        let missing = required.subtracting(keys).sorted()
        guard missing.isEmpty else {
            let labeled = missing.map { key in prefix.map { "\($0).\(key)" } ?? key }
            throw MusicTrackDecodeError.missingKeys(labeled)
        }
    }

    private static func jsonObject(_ data: Data) throws -> [String: Any] {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw MusicTrackDecodeError.notAnObject
        }
        guard let dict = object as? [String: Any] else {
            throw MusicTrackDecodeError.notAnObject
        }
        return dict
    }
}

enum MusicTrackFileCodec {
    private static let decoder = JSONDecoder()

    static func decodeManifest(_ data: Data) throws -> MusicTrackManifestV1 {
        try StrictMusicTrackJSON.validateKeys(data)
        let manifest = try decoder.decode(MusicTrackManifestV1.self, from: data)
        guard manifest.schemaVersion == MusicTrackManifestV1.currentSchemaVersion else {
            throw MusicTrackDecodeError.unsupportedSchemaVersion(manifest.schemaVersion)
        }
        guard !manifest.defaultTrackID.isEmpty else {
            throw MusicTrackDecodeError.emptyID
        }
        return manifest
    }

    static func runtimeTrack(from entry: MusicTrackFileEntryV1) throws -> MusicTrack {
        guard !entry.id.isEmpty else { throw MusicTrackDecodeError.emptyID }
        guard let game = AudioGameMode(rawValue: entry.game) else {
            throw MusicTrackDecodeError.invalidGame(entry.game)
        }
        let displayNameID = entry.displayNameID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayNameID.isEmpty else {
            throw MusicTrackDecodeError.emptyCreditField("displayNameID")
        }
        let resourcePath = entry.resourcePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resourcePath.isEmpty else {
            throw MusicTrackDecodeError.emptyResourcePath(field: "resourcePath")
        }
        let credit = try runtimeCredit(from: entry.credit)
        return MusicTrack(
            id: entry.id,
            game: game,
            displayNameID: displayNameID,
            resourcePath: resourcePath,
            credit: credit
        )
    }

    private static func runtimeCredit(from file: MusicTrackCreditFileV1) throws -> MusicTrackCredit {
        func required(_ value: String, field: String) throws -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw MusicTrackDecodeError.emptyCreditField(field)
            }
            return trimmed
        }

        let notice = file.attributionNotice?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return MusicTrackCredit(
            title: try required(file.title, field: "title"),
            author: try required(file.author, field: "author"),
            sourceURL: try required(file.sourceURL, field: "sourceURL"),
            license: try required(file.license, field: "license"),
            attributionNotice: (notice?.isEmpty == false) ? notice : nil
        )
    }
}
