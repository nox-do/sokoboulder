/// Structural decode of a Cave level JSON document (schema V1).
///
/// Presentation copy uses stable string IDs only. Titles and hints never belong
/// in the content hash.
public struct CaveLevelFileV1: Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: String
    public let game: LevelGameKind
    public let titleID: String
    public let tutorialHintID: String?
    public let width: Int
    public let height: Int
    public let rows: [String]
    public let rules: CaveLevelRulesV1

    public init(
        schemaVersion: Int = currentSchemaVersion,
        id: String,
        game: LevelGameKind = .cave,
        titleID: String,
        tutorialHintID: String? = nil,
        width: Int,
        height: Int,
        rows: [String],
        rules: CaveLevelRulesV1
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.game = game
        self.titleID = titleID
        self.tutorialHintID = tutorialHintID
        self.width = width
        self.height = height
        self.rows = rows
        self.rules = rules
    }
}

extension CaveLevelFileV1: Codable {
    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case game
        case titleID
        case tutorialHintID
        case width
        case height
        case rows
        case rules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        id = try container.decode(String.self, forKey: .id)
        game = try container.decode(LevelGameKind.self, forKey: .game)
        titleID = try container.decode(String.self, forKey: .titleID)
        tutorialHintID = try container.decodeIfPresent(String.self, forKey: .tutorialHintID)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        rows = try container.decode([String].self, forKey: .rows)
        rules = try container.decode(CaveLevelRulesV1.self, forKey: .rules)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(game, forKey: .game)
        try container.encode(titleID, forKey: .titleID)
        try container.encodeIfPresent(tutorialHintID, forKey: .tutorialHintID)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(rows, forKey: .rows)
        try container.encode(rules, forKey: .rules)
    }
}
