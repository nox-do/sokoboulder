import Foundation

/// Errors while decoding or structurally validating Cave level JSON.
public enum CaveLevelJSONError: Error, Equatable, Sendable {
    case invalidUTF8
    case decodingFailed(String)
    case unknownKeys([String])
    case missingKeys([String])
    case rulesNotObject
    case unknownRuleKeys([String])
    case missingRuleKeys([String])
    case unsupportedSchemaVersion(Int)
    case unsupportedGame(String)
    case emptyID
    case emptyTitleID
    case invalidRules(detail: String)
    case dimensionMismatch(declaredWidth: Int, declaredHeight: Int, rowCount: Int, firstRowWidth: Int?)
    case parse(CaveParseError)
}

/// Fully decoded, validated Cave level ready for the rule engine.
public struct DecodedCaveLevelFile: Equatable, Sendable {
    public let file: CaveLevelFileV1
    public let map: CaveASCIIMap
    public let level: CaveLevel
    /// SHA-256 hex of the canonical gameplay content (not presentation IDs).
    public let contentHash: String
}

/// Decodes Cave level JSON, then runs ASCII parse + structural build.
public enum CaveLevelJSONCodec {
    private static let decoder = JSONDecoder()
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }()

    public static func decode(_ data: Data) throws -> DecodedCaveLevelFile {
        do {
            try StrictCaveLevelJSON.validateKeys(data)
        } catch let error as StrictCaveLevelJSON.Error {
            throw mapStrictError(error)
        }

        let file: CaveLevelFileV1
        do {
            file = try decoder.decode(CaveLevelFileV1.self, from: data)
        } catch let error as DecodingError {
            throw CaveLevelJSONError.decodingFailed(String(describing: error))
        } catch {
            throw CaveLevelJSONError.decodingFailed(String(describing: error))
        }
        return try materialize(file)
    }

    public static func decode(json: String) throws -> DecodedCaveLevelFile {
        guard let data = json.data(using: .utf8) else {
            throw CaveLevelJSONError.invalidUTF8
        }
        return try decode(data)
    }

    public static func encode(_ file: CaveLevelFileV1) throws -> Data {
        try encoder.encode(file)
    }

    public static func materialize(_ file: CaveLevelFileV1) throws -> DecodedCaveLevelFile {
        guard file.schemaVersion == CaveLevelFileV1.currentSchemaVersion else {
            throw CaveLevelJSONError.unsupportedSchemaVersion(file.schemaVersion)
        }
        guard file.game == .cave else {
            throw CaveLevelJSONError.unsupportedGame(file.game.rawValue)
        }
        guard !file.id.isEmpty else {
            throw CaveLevelJSONError.emptyID
        }
        guard !file.titleID.isEmpty else {
            throw CaveLevelJSONError.emptyTitleID
        }
        guard file.rules.requiredDiamonds >= 0,
            file.rules.timeLimitTicks >= 0,
            file.rules.diamondValue >= 0,
            file.rules.extraDiamondValue >= 0
        else {
            throw CaveLevelJSONError.invalidRules(detail: "Rule values must be non-negative")
        }

        let firstWidth = file.rows.first?.count
        guard
            file.height == file.rows.count,
            file.width == (firstWidth ?? -1),
            file.width > 0,
            file.height > 0
        else {
            throw CaveLevelJSONError.dimensionMismatch(
                declaredWidth: file.width,
                declaredHeight: file.height,
                rowCount: file.rows.count,
                firstRowWidth: firstWidth
            )
        }

        let map: CaveASCIIMap
        do {
            map = try CaveASCIIParser.parse(file.rows.joined(separator: "\n"))
        } catch {
            throw CaveLevelJSONError.parse(error)
        }

        guard map.width == file.width, map.height == file.height else {
            throw CaveLevelJSONError.dimensionMismatch(
                declaredWidth: file.width,
                declaredHeight: file.height,
                rowCount: map.height,
                firstRowWidth: map.width
            )
        }

        let level: CaveLevel
        do {
            level = try CaveLevelBuilder.level(
                from: map,
                requiredDiamonds: file.rules.requiredDiamonds,
                timeLimitTicks: file.rules.timeLimitTicks,
                diamondValue: file.rules.diamondValue,
                extraDiamondValue: file.rules.extraDiamondValue
            )
        } catch let error as CaveParseError {
            throw CaveLevelJSONError.parse(error)
        }

        let contentHash = CaveContentHasher.sha256Hex(
            game: file.game,
            schemaVersion: file.schemaVersion,
            map: map,
            rules: file.rules
        )

        return DecodedCaveLevelFile(
            file: file,
            map: map,
            level: level,
            contentHash: contentHash
        )
    }

    private static func mapStrictError(_ error: StrictCaveLevelJSON.Error) -> CaveLevelJSONError {
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
        case .missingRuleKeys(let keys):
            return .missingRuleKeys(keys)
        }
    }
}
