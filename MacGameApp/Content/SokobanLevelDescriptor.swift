import Foundation
import GameCore

/// App-facing Sokoban level metadata for catalogs and persistence.
///
/// Runtime play still goes through validated ``SokobanLevel``; this descriptor
/// carries stable identity and the content hash used by run files.
struct SokobanLevelDescriptor: Equatable, Sendable {
    let id: String
    let title: String
    /// Source ASCII (canonical once parsed; indentation stripped by Swift literals).
    let ascii: String
    /// Lowercase hex SHA-256 of the canonical ASCII map encoding.
    let contentHash: String
    let tutorialHintID: String

    /// Builds a descriptor after parsing, validating, and hashing `ascii`.
    init(id: String, title: String, ascii: String, tutorialHintID: String) throws {
        _ = try SokobanLevelValidator.level(fromASCII: ascii)
        self.id = id
        self.title = title
        self.ascii = ascii
        self.contentHash = try SokobanContentHasher.sha256Hex(ascii: ascii)
        self.tutorialHintID = tutorialHintID
    }

    func makeLevel() throws -> SokobanLevel {
        try SokobanLevelValidator.level(fromASCII: ascii)
    }
}
