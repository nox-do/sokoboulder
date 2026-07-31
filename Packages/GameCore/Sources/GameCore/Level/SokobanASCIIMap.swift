/// Syntactic ASCII Sokoban map produced by ``SokobanASCIIParser``.
///
/// All rows have equal width and contain only known glyphs. Semantic checks
/// (player count, goals, crates) belong to ``SokobanLevelValidator``.
///
/// Construction is module-internal so callers cannot bypass the parser.
public struct SokobanASCIIMap: Equatable, Sendable {
    /// Level rows. Spaces are significant floor cells; do not trim.
    public let rows: [String]

    public var width: Int { rows.first?.count ?? 0 }
    public var height: Int { rows.count }

    init(rows: [String]) {
        self.rows = rows
    }

    public func character(at location: SourceLocation) -> Character? {
        let rowIndex = location.line - 1
        let columnIndex = location.column - 1
        guard rows.indices.contains(rowIndex) else { return nil }
        let row = rows[rowIndex]
        guard columnIndex >= 0, columnIndex < row.count else { return nil }
        let index = row.index(row.startIndex, offsetBy: columnIndex)
        return row[index]
    }
}

/// Errors while turning text into a syntactic ``SokobanASCIIMap``.
public enum SokobanParseError: Error, Equatable, Sendable {
    case emptyInput
    case inconsistentRowWidth(line: Int, expected: Int, actual: Int)
    case unknownCharacter(Character, at: SourceLocation)
}
