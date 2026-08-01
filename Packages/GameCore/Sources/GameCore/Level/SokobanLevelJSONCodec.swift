import Foundation

/// Errors while decoding or structurally validating Sokoban level JSON.
public enum SokobanLevelJSONError: Error, Equatable, Sendable {
    case invalidUTF8
    case decodingFailed(String)
    case unknownKeys([String])
    case missingKeys([String])
    case rulesNotObject
    case unknownRuleKeys([String])
    case unsupportedSchemaVersion(Int)
    case unsupportedGame(String)
    case emptyID
    case emptyTitleID
    case dimensionMismatch(declaredWidth: Int, declaredHeight: Int, rowCount: Int, firstRowWidth: Int?)
    case parse(SokobanParseError)
    case validation(SokobanValidationError)
}

/// Fully decoded, validated Sokoban level ready for the rule engine.
public struct DecodedSokobanLevelFile: Equatable, Sendable {
    public let file: SokobanLevelFileV1
    public let map: SokobanASCIIMap
    public let level: SokobanLevel
    /// SHA-256 hex of the canonical gameplay content (not presentation IDs).
    public let contentHash: String
}

/// Decodes Sokoban level JSON, then runs ASCII parse + semantic validation.
public enum SokobanLevelJSONCodec {
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }()

    /// Decodes UTF-8 JSON bytes into a validated level and content hash.
    public static func decode(_ data: Data) throws -> DecodedSokobanLevelFile {
        do {
            try StrictSokobanLevelJSON.validateKeys(data)
        } catch let error as StrictSokobanLevelJSON.Error {
            throw mapStrictError(error)
        }

        let file: SokobanLevelFileV1
        do {
            file = try decoder.decode(SokobanLevelFileV1.self, from: data)
        } catch let error as DecodingError {
            throw SokobanLevelJSONError.decodingFailed(String(describing: error))
        } catch {
            throw SokobanLevelJSONError.decodingFailed(String(describing: error))
        }
        return try materialize(file)
    }

    private static func mapStrictError(_ error: StrictSokobanLevelJSON.Error) -> SokobanLevelJSONError {
        switch error {
        case .notAnObject:
            return .decodingFailed("Top-level JSON value must be an object")
        case .unknownKeys(let keys):
            return .unknownKeys(keys)
        case .missingKeys(let keys):
            return .missingKeys(keys)
        case .rulesNotObject:
            return .rulesNotObject
        case .unknownRuleKeys(let keys):
            return .unknownRuleKeys(keys)
        }
    }

    /// Decodes a UTF-8 JSON string.
    public static func decode(json: String) throws -> DecodedSokobanLevelFile {
        guard let data = json.data(using: .utf8) else {
            throw SokobanLevelJSONError.invalidUTF8
        }
        return try decode(data)
    }

    /// Encodes a file DTO (pretty, sorted keys) for fixtures and round-trips.
    public static func encode(_ file: SokobanLevelFileV1) throws -> Data {
        try encoder.encode(file)
    }

    /// Structural checks + GameCore parse/validate + content hash.
    public static func materialize(_ file: SokobanLevelFileV1) throws -> DecodedSokobanLevelFile {
        guard file.schemaVersion == SokobanLevelFileV1.currentSchemaVersion else {
            throw SokobanLevelJSONError.unsupportedSchemaVersion(file.schemaVersion)
        }
        guard file.game == .sokoban else {
            throw SokobanLevelJSONError.unsupportedGame(file.game.rawValue)
        }
        guard !file.id.isEmpty else {
            throw SokobanLevelJSONError.emptyID
        }
        guard !file.titleID.isEmpty else {
            throw SokobanLevelJSONError.emptyTitleID
        }

        let firstWidth = file.rows.first?.count
        guard
            file.height == file.rows.count,
            file.width == (firstWidth ?? -1),
            file.width > 0,
            file.height > 0
        else {
            throw SokobanLevelJSONError.dimensionMismatch(
                declaredWidth: file.width,
                declaredHeight: file.height,
                rowCount: file.rows.count,
                firstRowWidth: firstWidth
            )
        }

        let ascii = file.rows.joined(separator: "\n")
        let map: SokobanASCIIMap
        do {
            map = try SokobanASCIIParser.parse(ascii)
        } catch {
            throw SokobanLevelJSONError.parse(error)
        }

        // Dimensions already checked against `file.rows`; parser may still reject glyphs.
        guard map.width == file.width, map.height == file.height else {
            throw SokobanLevelJSONError.dimensionMismatch(
                declaredWidth: file.width,
                declaredHeight: file.height,
                rowCount: map.height,
                firstRowWidth: map.width
            )
        }

        let level: SokobanLevel
        do {
            level = try SokobanLevelValidator.validate(map)
        } catch {
            throw SokobanLevelJSONError.validation(error)
        }

        let contentHash = SokobanContentHasher.sha256Hex(
            game: file.game,
            schemaVersion: file.schemaVersion,
            map: map,
            rules: file.rules
        )

        return DecodedSokobanLevelFile(
            file: file,
            map: map,
            level: level,
            contentHash: contentHash
        )
    }
}
