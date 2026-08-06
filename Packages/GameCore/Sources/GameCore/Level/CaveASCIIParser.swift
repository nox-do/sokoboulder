/// Parses ASCII cave maps for golden tests (Phase 3.7+).
///
/// Glyphs:
/// - ` ` floor (empty)
/// - `.` dirt
/// - `#` brick wall
/// - `X` steel wall
/// - `O` boulder on floor
/// - `*` diamond on floor
/// - `F` firefly on floor (heading left)
/// - `B` butterfly on floor (heading left)
/// - `M` magic wall
/// - `P` player on floor
/// - `E` closed exit
public enum CaveASCIIParser {
    public static let knownGlyphs: Set<Character> = [
        " ", ".", "#", "X", "O", "*", "F", "B", "M", "P", "E",
    ]

    public static func parse(_ text: String) throws(CaveParseError) -> CaveASCIIMap {
        let normalized = stripTrailingNewlineOnly(text)
        guard !normalized.isEmpty else {
            throw .emptyInput
        }

        let rows = splitPreservingEmpty(normalized)
        guard let first = rows.first, !first.isEmpty else {
            throw .emptyInput
        }

        let expectedWidth = first.count
        for (index, row) in rows.enumerated() {
            let line = index + 1
            if row.count != expectedWidth {
                throw .inconsistentRowWidth(
                    line: line,
                    expected: expectedWidth,
                    actual: row.count
                )
            }
            for (columnIndex, character) in row.enumerated() {
                if !knownGlyphs.contains(character) {
                    throw .unknownCharacter(
                        character,
                        at: SourceLocation(line: line, column: columnIndex + 1)
                    )
                }
            }
        }

        return CaveASCIIMap(rows: rows)
    }

    private static func stripTrailingNewlineOnly(_ text: String) -> String {
        var result = text
        if result.hasSuffix("\r\n") {
            result.removeLast(2)
        } else if result.hasSuffix("\n") || result.hasSuffix("\r") {
            result.removeLast()
        }
        return result
    }

    private static func splitPreservingEmpty(_ text: String) -> [String] {
        if text.isEmpty { return [] }
        var rows: [String] = []
        var current = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "\n" {
                rows.append(current)
                current = ""
            } else if character == "\r" {
                rows.append(current)
                current = ""
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "\n" {
                    index = next
                }
            } else {
                current.append(character)
            }
            index = text.index(after: index)
        }
        rows.append(current)
        return rows
    }
}

public struct CaveASCIIMap: Equatable, Sendable {
    public let rows: [String]

    public var width: Int { rows.first?.count ?? 0 }
    public var height: Int { rows.count }

    public init(rows: [String]) {
        self.rows = rows
    }
}

public enum CaveParseError: Error, Equatable, Sendable {
    case emptyInput
    case inconsistentRowWidth(line: Int, expected: Int, actual: Int)
    case unknownCharacter(Character, at: SourceLocation)
    case missingPlayer
    case multiplePlayers
    case missingExit
    case occupantOnNonFloor
}

public enum CaveLevelBuilder {
    /// Builds a ``CaveLevel`` from ASCII. `requiredDiamonds` defaults to the
    /// diamond glyph count when `nil`.
    public static func level(
        fromASCII text: String,
        requiredDiamonds: Int? = nil,
        timeLimitTicks: Int = 1_000,
        diamondValue: Int = 10,
        extraDiamondValue: Int = 15,
        magicWallMillingTicks: Int = CaveLevelRulesV1.defaultMagicWallMillingTicks
    ) throws -> CaveLevel {
        let map = try CaveASCIIParser.parse(text)
        return try level(
            from: map,
            requiredDiamonds: requiredDiamonds,
            timeLimitTicks: timeLimitTicks,
            diamondValue: diamondValue,
            extraDiamondValue: extraDiamondValue,
            magicWallMillingTicks: magicWallMillingTicks
        )
    }

    public static func level(
        from map: CaveASCIIMap,
        requiredDiamonds: Int? = nil,
        timeLimitTicks: Int = 1_000,
        diamondValue: Int = 10,
        extraDiamondValue: Int = 15,
        magicWallMillingTicks: Int = CaveLevelRulesV1.defaultMagicWallMillingTicks
    ) throws -> CaveLevel {
        var terrains: [CaveTerrain] = []
        terrains.reserveCapacity(map.width * map.height)
        var playerStart: GridPosition?
        var occupants: [CaveOccupantStart] = []
        var diamondCount = 0
        var exitCount = 0

        for row in 0..<map.height {
            let line = map.rows[row]
            for (column, character) in line.enumerated() {
                let position = GridPosition(column: column, row: row)
                switch character {
                case " ":
                    terrains.append(.floor)
                case ".":
                    terrains.append(.dirt)
                case "#":
                    terrains.append(.wall)
                case "X":
                    terrains.append(.steelWall)
                case "M":
                    terrains.append(.magicWall)
                case "E":
                    terrains.append(.exit(.closed))
                    exitCount += 1
                case "O":
                    terrains.append(.floor)
                    occupants.append(CaveOccupantStart(position: position, kind: .boulder))
                case "*":
                    terrains.append(.floor)
                    occupants.append(CaveOccupantStart(position: position, kind: .diamond))
                    diamondCount += 1
                case "F":
                    terrains.append(.floor)
                    occupants.append(CaveOccupantStart(position: position, kind: .firefly))
                case "B":
                    terrains.append(.floor)
                    occupants.append(CaveOccupantStart(position: position, kind: .butterfly))
                case "P":
                    terrains.append(.floor)
                    if playerStart != nil {
                        throw CaveParseError.multiplePlayers
                    }
                    playerStart = position
                default:
                    throw CaveParseError.unknownCharacter(
                        character,
                        at: SourceLocation(line: row + 1, column: column + 1)
                    )
                }
            }
        }

        guard let player = playerStart else {
            throw CaveParseError.missingPlayer
        }
        guard exitCount >= 1 else {
            throw CaveParseError.missingExit
        }

        let required = requiredDiamonds ?? diamondCount
        let terrainGrid = Grid(width: map.width, height: map.height, cells: terrains)
        return CaveLevel(
            width: map.width,
            height: map.height,
            terrain: terrainGrid,
            playerStart: player,
            occupantStarts: occupants,
            requiredDiamonds: required,
            timeLimitTicks: timeLimitTicks,
            diamondValue: diamondValue,
            extraDiamondValue: extraDiamondValue,
            magicWallMillingTicks: magicWallMillingTicks
        )
    }
}
