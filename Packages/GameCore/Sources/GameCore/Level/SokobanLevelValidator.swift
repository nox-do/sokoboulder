/// Semantic errors for a syntactically valid ``SokobanASCIIMap``.
public enum SokobanValidationError: Error, Equatable, Sendable {
    case emptyLevel
    case noPlayer
    case multiplePlayers([SourceLocation])
    case noGoals
    case crateGoalMismatch(crates: Int, goals: Int)
}

/// Turns a syntactic ASCII map into a validated ``SokobanLevel``.
///
/// Hard errors only — corner crates, unreachable areas, and presumed
/// unsolvability are not rejected here.
public enum SokobanLevelValidator {
    public static func validate(_ map: SokobanASCIIMap) throws(SokobanValidationError) -> SokobanLevel {
        guard map.height > 0, map.width > 0 else {
            throw .emptyLevel
        }

        var terrainCells: [SokobanTerrain] = []
        terrainCells.reserveCapacity(map.width * map.height)

        var playerLocations: [SourceLocation] = []
        var crateStarts: [GridPosition] = []
        var goalCount = 0

        for (rowIndex, row) in map.rows.enumerated() {
            for (columnIndex, character) in row.enumerated() {
                let location = SourceLocation(line: rowIndex + 1, column: columnIndex + 1)
                let position = GridPosition(column: columnIndex, row: rowIndex)
                let decoded = decode(character)

                terrainCells.append(decoded.terrain)

                if decoded.isGoal {
                    goalCount += 1
                }
                if decoded.hasPlayer {
                    playerLocations.append(location)
                }
                if decoded.hasCrate {
                    crateStarts.append(position)
                }
            }
        }

        switch playerLocations.count {
        case 0:
            throw .noPlayer
        case 1:
            break
        default:
            throw .multiplePlayers(playerLocations)
        }

        guard goalCount > 0 else {
            throw .noGoals
        }

        guard crateStarts.count == goalCount else {
            throw .crateGoalMismatch(crates: crateStarts.count, goals: goalCount)
        }

        let playerLocation = playerLocations[0]
        let playerStart = GridPosition(
            column: playerLocation.column - 1,
            row: playerLocation.line - 1
        )

        let terrain = Grid(width: map.width, height: map.height, cells: terrainCells)
        return SokobanLevel(
            terrain: terrain,
            playerStart: playerStart,
            crateStarts: crateStarts
        )
    }

    /// Convenience: parse then validate.
    public static func level(fromASCII text: String) throws -> SokobanLevel {
        let map = try SokobanASCIIParser.parse(text)
        return try validate(map)
    }

    private struct DecodedGlyph {
        let terrain: SokobanTerrain
        let hasPlayer: Bool
        let hasCrate: Bool
        var isGoal: Bool { terrain == .goal }
    }

    private static func decode(_ character: Character) -> DecodedGlyph {
        switch character {
        case "-":
            return DecodedGlyph(terrain: .void, hasPlayer: false, hasCrate: false)
        case " ":
            return DecodedGlyph(terrain: .floor, hasPlayer: false, hasCrate: false)
        case "#":
            return DecodedGlyph(terrain: .wall, hasPlayer: false, hasCrate: false)
        case ".":
            return DecodedGlyph(terrain: .goal, hasPlayer: false, hasCrate: false)
        case "$":
            return DecodedGlyph(terrain: .floor, hasPlayer: false, hasCrate: true)
        case "*":
            return DecodedGlyph(terrain: .goal, hasPlayer: false, hasCrate: true)
        case "@":
            return DecodedGlyph(terrain: .floor, hasPlayer: true, hasCrate: false)
        case "+":
            return DecodedGlyph(terrain: .goal, hasPlayer: true, hasCrate: false)
        default:
            preconditionFailure("Unknown glyph reached validator: \(character)")
        }
    }
}
