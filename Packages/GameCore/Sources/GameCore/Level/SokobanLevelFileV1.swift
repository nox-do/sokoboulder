/// Supported game kinds in level JSON (schema V1).
public enum LevelGameKind: String, Codable, Sendable, Equatable {
    case sokoban
}

/// Structural decode of a Sokoban level JSON document (schema V1).
///
/// Presentation copy uses stable string IDs only. Titles, hints, textures, and
/// audio never belong in the content hash.
public struct SokobanLevelFileV1: Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: String
    public let game: LevelGameKind
    public let titleID: String
    public let goalTextID: String?
    public let tutorialHintID: String?
    public let width: Int
    public let height: Int
    public let rows: [String]
    public let rules: SokobanLevelRulesV1

    public init(
        schemaVersion: Int = currentSchemaVersion,
        id: String,
        game: LevelGameKind = .sokoban,
        titleID: String,
        goalTextID: String? = nil,
        tutorialHintID: String? = nil,
        width: Int,
        height: Int,
        rows: [String],
        rules: SokobanLevelRulesV1 = SokobanLevelRulesV1()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.game = game
        self.titleID = titleID
        self.goalTextID = goalTextID
        self.tutorialHintID = tutorialHintID
        self.width = width
        self.height = height
        self.rows = rows
        self.rules = rules
    }
}

extension SokobanLevelFileV1: Codable {
    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case game
        case titleID
        case goalTextID
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
        goalTextID = try container.decodeIfPresent(String.self, forKey: .goalTextID)
        tutorialHintID = try container.decodeIfPresent(String.self, forKey: .tutorialHintID)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        rows = try container.decode([String].self, forKey: .rows)
        rules = try container.decode(SokobanLevelRulesV1.self, forKey: .rules)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(game, forKey: .game)
        try container.encode(titleID, forKey: .titleID)
        try container.encodeIfPresent(goalTextID, forKey: .goalTextID)
        try container.encodeIfPresent(tutorialHintID, forKey: .tutorialHintID)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(rows, forKey: .rows)
        try container.encode(rules, forKey: .rules)
    }
}
