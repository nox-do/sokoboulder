import Foundation

/// Audio theme catalog index (paths only).
struct AudioThemeManifestV1: Equatable, Codable, Sendable {
    static let currentSchemaVersion = 1
    static let resourcePath = "Audio/manifest.json"

    let schemaVersion: Int
    let themes: [String]
    let defaultThemeID: String
}

/// Versioned audio theme document helpers (strict JSON → runtime theme).
enum AudioThemeFileV1 {
    static let currentSchemaVersion = 1
}

enum StrictAudioThemeJSON {
    private static let manifestAllowed: Set<String> = [
        "schemaVersion", "themes", "defaultThemeID",
    ]
    private static let manifestRequired = manifestAllowed

    private static let themeAllowed: Set<String> = [
        "schemaVersion", "id", "game", "music", "cues",
    ]
    private static let themeRequired = themeAllowed

    private static let musicAllowed: Set<String> = ["playing"]
    private static let musicRequired: Set<String> = []

    private static let knownCueKeys = Set(AudioCue.allCases.map(\.rawValue))

    static func validateManifestKeys(_ data: Data) throws {
        try validateObjectKeys(try jsonObject(data), allowed: manifestAllowed, required: manifestRequired)
    }

    static func validateThemeKeys(_ data: Data) throws {
        let root = try jsonObject(data)
        try validateObjectKeys(root, allowed: themeAllowed, required: themeRequired)

        let music = try nested(root, "music")
        try validateObjectKeys(music, allowed: musicAllowed, required: musicRequired)

        guard let cues = root["cues"] as? [String: Any] else {
            throw AudioThemeDecodeError.missingKeys(["cues"])
        }
        let cueKeys = Set(cues.keys)
        let unknownCues = cueKeys.subtracting(knownCueKeys).sorted()
        guard unknownCues.isEmpty else {
            throw AudioThemeDecodeError.unknownKeys(unknownCues.map { "cues.\($0)" })
        }
        let missingCues = knownCueKeys.subtracting(cueKeys).sorted()
        guard missingCues.isEmpty else {
            throw AudioThemeDecodeError.missingKeys(missingCues.map { "cues.\($0)" })
        }
    }

    private static func validateObjectKeys(
        _ object: [String: Any],
        allowed: Set<String>,
        required: Set<String>
    ) throws {
        let keys = Set(object.keys)
        let unknown = keys.subtracting(allowed).sorted()
        guard unknown.isEmpty else { throw AudioThemeDecodeError.unknownKeys(unknown) }
        let missing = required.subtracting(keys).sorted()
        guard missing.isEmpty else { throw AudioThemeDecodeError.missingKeys(missing) }
    }

    private static func nested(_ object: [String: Any], _ key: String) throws -> [String: Any] {
        guard let nested = object[key] as? [String: Any] else {
            throw AudioThemeDecodeError.missingKeys([key])
        }
        return nested
    }

    private static func jsonObject(_ data: Data) throws -> [String: Any] {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw AudioThemeDecodeError.notAnObject
        }
        guard let dict = object as? [String: Any] else {
            throw AudioThemeDecodeError.notAnObject
        }
        return dict
    }
}

enum AudioThemeFileCodec {
    private static let decoder = JSONDecoder()

    static func decodeManifest(_ data: Data) throws -> AudioThemeManifestV1 {
        try StrictAudioThemeJSON.validateManifestKeys(data)
        let manifest = try decoder.decode(AudioThemeManifestV1.self, from: data)
        guard manifest.schemaVersion == AudioThemeManifestV1.currentSchemaVersion else {
            throw AudioThemeDecodeError.unsupportedSchemaVersion(manifest.schemaVersion)
        }
        guard !manifest.defaultThemeID.isEmpty else {
            throw AudioThemeDecodeError.emptyID
        }
        return manifest
    }

    static func decodeTheme(_ data: Data) throws -> AudioTheme {
        try StrictAudioThemeJSON.validateThemeKeys(data)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AudioThemeDecodeError.notAnObject
        }

        guard let schemaVersion = root["schemaVersion"] as? Int else {
            throw AudioThemeDecodeError.missingKeys(["schemaVersion"])
        }
        guard schemaVersion == AudioThemeFileV1.currentSchemaVersion else {
            throw AudioThemeDecodeError.unsupportedSchemaVersion(schemaVersion)
        }
        guard let id = root["id"] as? String, !id.isEmpty else {
            throw AudioThemeDecodeError.emptyID
        }
        guard let gameRaw = root["game"] as? String else {
            throw AudioThemeDecodeError.missingKeys(["game"])
        }
        guard let gameMode = AudioGameMode(rawValue: gameRaw) else {
            throw AudioThemeDecodeError.invalidGame(gameRaw)
        }
        guard let music = root["music"] as? [String: Any] else {
            throw AudioThemeDecodeError.missingKeys(["music"])
        }
        guard let cues = root["cues"] as? [String: Any] else {
            throw AudioThemeDecodeError.missingKeys(["cues"])
        }

        let musicPath: String?
        if music["playing"] is NSNull || music["playing"] == nil {
            musicPath = nil
        } else if let playing = music["playing"] as? String {
            let trimmed = playing.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw AudioThemeDecodeError.emptyResourcePath(field: "music.playing")
            }
            musicPath = trimmed
        } else {
            throw AudioThemeDecodeError.emptyResourcePath(field: "music.playing")
        }

        var cuePaths: [AudioCue: String] = [:]
        for (key, value) in cues {
            guard let cue = AudioCue(rawValue: key) else {
                throw AudioThemeDecodeError.invalidCueKey(key)
            }
            if value is NSNull {
                continue
            }
            guard let path = value as? String else {
                throw AudioThemeDecodeError.emptyResourcePath(field: "cues.\(key)")
            }
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw AudioThemeDecodeError.emptyResourcePath(field: "cues.\(key)")
            }
            cuePaths[cue] = trimmed
        }

        return AudioTheme(
            id: id,
            game: gameMode,
            musicPlayingPath: musicPath,
            cueResourcePaths: cuePaths
        )
    }
}
