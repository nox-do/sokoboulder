import Foundation

/// Ordered music-track catalog with code fallbacks for known IDs.
struct MusicTrackCatalog: Equatable, Sendable {
    let tracks: [MusicTrack]
    /// Per-game default track IDs.
    let defaultTrackIDs: [AudioGameMode: String]

    /// Sokoban default (legacy convenience).
    var defaultTrackID: String {
        defaultTrackID(for: .sokoban)
    }

    func defaultTrackID(for game: AudioGameMode) -> String {
        if let id = defaultTrackIDs[game] {
            return id
        }
        return tracks(for: game).first?.id ?? MusicTrack.puzzlingID
    }

    func track(id: String) -> MusicTrack? {
        tracks.first { $0.id == id }
    }

    func tracks(for game: AudioGameMode) -> [MusicTrack] {
        tracks.filter { $0.game == game }
    }

    /// Tracks offered in settings for the given game (empty → hide picker).
    func selectableTracks(for game: AudioGameMode) -> [MusicTrack] {
        tracks(for: game)
    }

    /// Resolves a preferred ID for `game`, falling back to default then first track.
    func resolvedTrack(preferredID: String, for game: AudioGameMode) -> MusicTrack? {
        let options = tracks(for: game)
        guard !options.isEmpty else { return nil }
        if let match = options.first(where: { $0.id == preferredID }) {
            return match
        }
        let fallbackID = defaultTrackID(for: game)
        if let def = options.first(where: { $0.id == fallbackID }) {
            return def
        }
        return options.first
    }
}

enum MusicTrackCatalogLoader {
    /// Loads tracks from a resource provider. Falls back to built-ins on any catalog failure.
    static func load(from resources: any ContentResourceProvider) -> MusicTrackCatalog {
        do {
            return try loadStrict(from: resources)
        } catch {
            return MusicTrackCatalog(
                tracks: BuiltInMusicTracks.allFallbacks(),
                defaultTrackIDs: BuiltInMusicTracks.defaultTrackIDs()
            )
        }
    }

    static func loadStrict(from resources: any ContentResourceProvider) throws -> MusicTrackCatalog {
        let data = try resources.data(at: MusicTrackManifestV1.resourcePath)
        let manifest = try MusicTrackFileCodec.decodeManifest(data)

        var tracks: [MusicTrack] = []
        var seenIDs = Set<String>()

        for entry in manifest.tracks {
            let track = try MusicTrackFileCodec.runtimeTrack(from: entry)
            guard seenIDs.insert(track.id).inserted else {
                throw MusicTrackDecodeError.duplicateTrackID(track.id)
            }
            tracks.append(track)
        }

        guard !tracks.isEmpty else {
            throw MusicTrackDecodeError.missingTrack(id: manifest.defaultTrackID)
        }
        guard tracks.contains(where: { $0.id == manifest.defaultTrackID }) else {
            throw MusicTrackDecodeError.missingTrack(id: manifest.defaultTrackID)
        }

        var defaults = BuiltInMusicTracks.defaultTrackIDs()
        defaults[.sokoban] = manifest.defaultTrackID
        if let byGame = manifest.defaultsByGame {
            for (rawGame, trackID) in byGame {
                guard let game = AudioGameMode(rawValue: rawGame) else {
                    throw MusicTrackDecodeError.invalidGame(rawGame)
                }
                guard tracks.contains(where: { $0.id == trackID && $0.game == game }) else {
                    throw MusicTrackDecodeError.missingTrack(id: trackID)
                }
                defaults[game] = trackID
            }
        }

        for fallback in BuiltInMusicTracks.allFallbacks()
        where !tracks.contains(where: { $0.id == fallback.id }) {
            tracks.append(fallback)
        }

        return MusicTrackCatalog(tracks: tracks, defaultTrackIDs: defaults)
    }
}
