/// Gameplay rules embedded in a Cave level file (schema V1).
///
/// Unknown keys are rejected. Optional value fields default when omitted so
/// older draft files stay valid; present keys must be non-negative integers.
public struct CaveLevelRulesV1: Equatable, Sendable {
    public var requiredDiamonds: Int
    public var timeLimitTicks: Int
    public var diamondValue: Int
    public var extraDiamondValue: Int
    /// Milling duration once any magic wall activates. Default ~20s at 10 Hz.
    public var magicWallMillingTicks: Int
    /// Seed for ``DeterministicRNG`` (amoeba growth). `0` remaps to `1` at start.
    public var rngSeed: UInt32
    /// Ticks spent in slow amoeba growth before switching to fast probability.
    public var amoebaSlowGrowthTicks: Int
    /// Max amoeba cells before boulder conversion. `0` = auto from cave size.
    public var amoebaMaxCells: Int

    public static let defaultMagicWallMillingTicks = 200
    public static let defaultRngSeed: UInt32 = 1
    public static let defaultAmoebaSlowGrowthTicks = 200
    /// Classic C64 absolute threshold; used when auto formula would be smaller.
    public static let classicAmoebaMaxCells = 200

    public init(
        requiredDiamonds: Int,
        timeLimitTicks: Int,
        diamondValue: Int = 10,
        extraDiamondValue: Int = 15,
        magicWallMillingTicks: Int = Self.defaultMagicWallMillingTicks,
        rngSeed: UInt32 = Self.defaultRngSeed,
        amoebaSlowGrowthTicks: Int = Self.defaultAmoebaSlowGrowthTicks,
        amoebaMaxCells: Int = 0
    ) {
        self.requiredDiamonds = requiredDiamonds
        self.timeLimitTicks = timeLimitTicks
        self.diamondValue = diamondValue
        self.extraDiamondValue = extraDiamondValue
        self.magicWallMillingTicks = magicWallMillingTicks
        self.rngSeed = rngSeed
        self.amoebaSlowGrowthTicks = amoebaSlowGrowthTicks
        self.amoebaMaxCells = amoebaMaxCells
    }

    /// BDCFF ~22.7% of cave cells, floored, at least 20; `requested > 0` wins.
    public static func resolvedAmoebaMaxCells(requested: Int, width: Int, height: Int) -> Int {
        if requested > 0 { return requested }
        let auto = Int((Double(width * height) * 0.227).rounded(.down))
        return max(20, auto)
    }

    /// Compact canonical JSON for content hashing (sorted keys).
    public var canonicalJSON: String {
        "{"
            + "\"amoebaMaxCells\":\(amoebaMaxCells),"
            + "\"amoebaSlowGrowthTicks\":\(amoebaSlowGrowthTicks),"
            + "\"diamondValue\":\(diamondValue),"
            + "\"extraDiamondValue\":\(extraDiamondValue),"
            + "\"magicWallMillingTicks\":\(magicWallMillingTicks),"
            + "\"requiredDiamonds\":\(requiredDiamonds),"
            + "\"rngSeed\":\(rngSeed),"
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
        case magicWallMillingTicks
        case rngSeed
        case amoebaSlowGrowthTicks
        case amoebaMaxCells
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
            CodingKeys.magicWallMillingTicks.rawValue,
            CodingKeys.rngSeed.rawValue,
            CodingKeys.amoebaSlowGrowthTicks.rawValue,
            CodingKeys.amoebaMaxCells.rawValue,
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
        magicWallMillingTicks =
            try container.decodeIfPresent(Int.self, forKey: .magicWallMillingTicks)
            ?? Self.defaultMagicWallMillingTicks
        if let seedInt = try container.decodeIfPresent(Int.self, forKey: .rngSeed) {
            guard seedInt >= 0, seedInt <= Int(UInt32.max) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .rngSeed,
                    in: container,
                    debugDescription: "rngSeed must fit in UInt32"
                )
            }
            rngSeed = UInt32(seedInt)
        } else {
            rngSeed = Self.defaultRngSeed
        }
        amoebaSlowGrowthTicks =
            try container.decodeIfPresent(Int.self, forKey: .amoebaSlowGrowthTicks)
            ?? Self.defaultAmoebaSlowGrowthTicks
        amoebaMaxCells = try container.decodeIfPresent(Int.self, forKey: .amoebaMaxCells) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requiredDiamonds, forKey: .requiredDiamonds)
        try container.encode(timeLimitTicks, forKey: .timeLimitTicks)
        try container.encode(diamondValue, forKey: .diamondValue)
        try container.encode(extraDiamondValue, forKey: .extraDiamondValue)
        try container.encode(magicWallMillingTicks, forKey: .magicWallMillingTicks)
        try container.encode(rngSeed, forKey: .rngSeed)
        try container.encode(amoebaSlowGrowthTicks, forKey: .amoebaSlowGrowthTicks)
        try container.encode(amoebaMaxCells, forKey: .amoebaMaxCells)
    }
}
