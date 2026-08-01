import Foundation

/// Campaign manifest schema V1 (bundle index only — no duplicated level metadata).
struct ContentManifestV1: Equatable, Codable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let campaigns: [Campaign]
    let defaultThemeID: String?
    let defaultAudioThemeID: String?

    struct Campaign: Equatable, Codable, Sendable {
        let id: String
        /// Bundle-relative paths to level JSON files; order is unlock order.
        let levels: [String]
    }

    init(
        schemaVersion: Int = currentSchemaVersion,
        campaigns: [Campaign],
        defaultThemeID: String? = nil,
        defaultAudioThemeID: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.campaigns = campaigns
        self.defaultThemeID = defaultThemeID
        self.defaultAudioThemeID = defaultAudioThemeID
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case campaigns
        case defaultThemeID
        case defaultAudioThemeID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        campaigns = try container.decode([Campaign].self, forKey: .campaigns)
        defaultThemeID = try container.decodeIfPresent(String.self, forKey: .defaultThemeID)
        defaultAudioThemeID = try container.decodeIfPresent(String.self, forKey: .defaultAudioThemeID)
    }
}
