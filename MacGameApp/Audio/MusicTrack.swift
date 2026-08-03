import Foundation

/// One selectable background track with per-song license credits.
struct MusicTrack: Equatable, Sendable, Identifiable {
    static let puzzlingID = "music.sokoban.puzzling"
    static let preludeID = "music.sokoban.prelude"
    static let caveWonderID = "music.cave.wonder"
    static let caveTinkeringID = "music.cave.tinkering"
    static let knownIDs = [puzzlingID, preludeID, caveWonderID, caveTinkeringID]

    let id: String
    let game: AudioGameMode
    /// Localization key for the settings label.
    let displayNameID: String
    /// Bundle-relative audio path.
    let resourcePath: String
    let credit: MusicTrackCredit
}

/// Attribution payload kept with the track (not only in THIRD_PARTY_NOTICES).
struct MusicTrackCredit: Equatable, Sendable {
    let title: String
    let author: String
    let sourceURL: String
    /// Short license label, e.g. `CC0 1.0` or `CC-BY 3.0`.
    let license: String
    /// Required attribution text when the license demands it (CC-BY).
    let attributionNotice: String?

    /// One-line credit for settings / about surfaces.
    var summaryLine: String {
        "\(title) — \(author) (\(license))"
    }
}
