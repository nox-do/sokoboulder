import Foundation
import GameCore

/// App-facing Cave level metadata for catalogs and progression.
struct CaveLevelDescriptor: Equatable, Sendable {
    let id: String
    let titleID: String
    let tutorialHintID: String?
    let rows: [String]
    let contentHash: String
    let requiredDiamonds: Int
    let timeLimitTicks: Int
    private let level: CaveLevel

    init(decoded: DecodedCaveLevelFile) {
        self.id = decoded.file.id
        self.titleID = decoded.file.titleID
        self.tutorialHintID = decoded.file.tutorialHintID
        self.rows = decoded.map.rows
        self.contentHash = decoded.contentHash
        self.requiredDiamonds = decoded.file.rules.requiredDiamonds
        self.timeLimitTicks = decoded.file.rules.timeLimitTicks
        self.level = decoded.level
    }

    func makeLevel() -> CaveLevel {
        level
    }
}
