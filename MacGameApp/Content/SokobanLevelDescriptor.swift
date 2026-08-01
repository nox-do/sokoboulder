import Foundation
import GameCore

/// App-facing Sokoban level metadata for catalogs and persistence.
///
/// Runtime play still goes through validated ``SokobanLevel``; this descriptor
/// carries stable identity and the content hash used by run files. Presentation
/// copy is referenced by string ID and resolved via ``ContentStringTable``.
struct SokobanLevelDescriptor: Equatable, Sendable {
    let id: String
    let titleID: String
    let goalTextID: String?
    let tutorialHintID: String?
    /// Source map rows (canonical once parsed).
    let rows: [String]
    /// Lowercase hex SHA-256 of the canonical gameplay content encoding.
    let contentHash: String
    private let level: SokobanLevel

    /// Builds a descriptor from a decoded, validated level file.
    init(decoded: DecodedSokobanLevelFile) {
        self.id = decoded.file.id
        self.titleID = decoded.file.titleID
        self.goalTextID = decoded.file.goalTextID
        self.tutorialHintID = decoded.file.tutorialHintID
        self.rows = decoded.map.rows
        self.contentHash = decoded.contentHash
        self.level = decoded.level
    }

    /// Test helper: parse ASCII, validate, and hash with Sokoban V1 defaults.
    init(
        id: String,
        titleID: String,
        ascii: String,
        tutorialHintID: String? = nil,
        goalTextID: String? = nil
    ) throws {
        let map = try SokobanASCIIParser.parse(ascii)
        let file = SokobanLevelFileV1(
            id: id,
            titleID: titleID,
            goalTextID: goalTextID,
            tutorialHintID: tutorialHintID,
            width: map.width,
            height: map.height,
            rows: map.rows
        )
        self.init(decoded: try SokobanLevelJSONCodec.materialize(file))
    }

    func makeLevel() -> SokobanLevel {
        level
    }
}
