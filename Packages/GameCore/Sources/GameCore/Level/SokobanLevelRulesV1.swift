/// Gameplay rules embedded in a Sokoban level file (schema V1).
///
/// V1 has no tunable parameters. The object must be exactly `{}`; any field is
/// rejected so typos like `moveLimit` cannot silently disappear from the hash.
public struct SokobanLevelRulesV1: Equatable, Codable, Sendable {
    public init() {}

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        guard container.allKeys.isEmpty else {
            let keys = container.allKeys.map(\.stringValue).sorted()
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "SokobanLevelRulesV1 rejects unknown keys: \(keys.joined(separator: ", "))"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        _ = encoder.container(keyedBy: AnyKey.self)
    }

    /// Compact canonical JSON for content hashing (sorted keys when fields exist).
    public var canonicalJSON: String { "{}" }
}
