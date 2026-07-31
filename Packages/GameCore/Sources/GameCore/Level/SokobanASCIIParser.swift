/// Parses ASCII Sokoban text into a syntactic ``SokobanASCIIMap``.
///
/// Glyphs (spaces are floor — never trim row content):
/// - `#` wall
/// - ` ` floor
/// - `.` goal
/// - `$` crate on floor
/// - `@` player on floor
/// - `*` crate on goal
/// - `+` player on goal
/// - `-` void (non-walkable exterior)
public enum SokobanASCIIParser {
    public static let knownGlyphs: Set<Character> = [
        "#", " ", ".", "$", "@", "*", "+", "-",
    ]

    /// Parses `text` into a map.
    ///
    /// Only a single trailing newline (LF or CRLF) is stripped so editors can
    /// end the file with a newline without creating an empty final row. Leading
    /// or internal whitespace is never trimmed.
    public static func parse(_ text: String) throws(SokobanParseError) -> SokobanASCIIMap {
        let normalized = stripTrailingNewlineOnly(text)
        guard !normalized.isEmpty else {
            throw .emptyInput
        }

        let rows = splitPreservingEmpty(normalized)
        guard let first = rows.first else {
            throw .emptyInput
        }

        let expectedWidth = first.count
        guard expectedWidth > 0 else {
            throw .emptyInput
        }

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

        return SokobanASCIIMap(rows: rows)
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
