/// Gameplay rules embedded in a Cave level file (schema V1).
///
/// Unknown keys are rejected. Optional value fields default when omitted so
/// older draft files stay valid; present keys must be non-negative integers.
public struct CaveLevelRulesV1: Equatable, Sendable {
    public var requiredDiamonds: Int
    public var timeLimitTicks: Int
    public var diamondValue: Int
    public var extraDiamondValue: Int

    public init(
        requiredDiamonds: Int,
        timeLimitTicks: Int,
        diamondValue: Int = 10,
        extraDiamondValue: Int = 15
    ) {
        self.requiredDiamonds = requiredDiamonds
        self.timeLimitTicks = timeLimitTicks
        self.diamondValue = diamondValue
        self.extraDiamondValue = extraDiamondValue
    }

    /// Compact canonical JSON for content hashing (sorted keys).
    public var canonicalJSON: String {
        "{"
            + "\"diamondValue\":\(diamondValue),"
            + "\"extraDiamondValue\":\(extraDiamondValue),"
            + "\"requiredDiamonds\":\(requiredDiamonds),"
            + "\"timeLimitTicks\":\(timeLimitTicks)"
            + "}"
    }
}

extension CaveLevelRulesV1: Codable {
    enum CodingKeys: String, CodingKey {
        case requiredDiamonds
        case timeLimitTicks
        case diamondValue
        case extraDiamondValue
    }

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
        let probe = try decoder.container(keyedBy: AnyKey.self)
        let allowed: Set<String> = [
            CodingKeys.requiredDiamonds.rawValue,
            CodingKeys.timeLimitTicks.rawValue,
            CodingKeys.diamondValue.rawValue,
            CodingKeys.extraDiamondValue.rawValue,
        ]
        let unknown = probe.allKeys.map(\.stringValue).filter { !allowed.contains($0) }.sorted()
        guard unknown.isEmpty else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription:
                        "CaveLevelRulesV1 rejects unknown keys: \(unknown.joined(separator: ", "))"
                )
            )
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        requiredDiamonds = try container.decode(Int.self, forKey: .requiredDiamonds)
        timeLimitTicks = try container.decode(Int.self, forKey: .timeLimitTicks)
        diamondValue = try container.decodeIfPresent(Int.self, forKey: .diamondValue) ?? 10
        extraDiamondValue = try container.decodeIfPresent(Int.self, forKey: .extraDiamondValue) ?? 15
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requiredDiamonds, forKey: .requiredDiamonds)
        try container.encode(timeLimitTicks, forKey: .timeLimitTicks)
        try container.encode(diamondValue, forKey: .diamondValue)
        try container.encode(extraDiamondValue, forKey: .extraDiamondValue)
    }
}
