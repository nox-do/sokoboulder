import Foundation

/// Ordered audio theme catalog with code fallbacks for known IDs.
struct AudioThemeCatalog: Equatable, Sendable {
    let themes: [AudioTheme]
    let defaultThemeID: String

    func theme(id: String) -> AudioTheme? {
        themes.first { $0.id == id }
    }

    func theme(for game: AudioGameMode) -> AudioTheme? {
        themes.first { $0.game == game }
    }

    func resolvedTheme(for game: AudioGameMode) -> AudioTheme {
        if let theme = theme(for: game) {
            return theme
        }
        if let theme = theme(id: defaultThemeID) {
            return theme
        }
        return BuiltInAudioThemes.fallback(id: defaultThemeID)
    }
}

enum AudioThemeCatalogLoader {
    /// Loads themes from a resource provider. Falls back to built-ins on any catalog failure.
    ///
    /// Asset files referenced by themes are not required to exist at load time.
    static func load(from resources: any ContentResourceProvider) -> AudioThemeCatalog {
        do {
            return try loadStrict(from: resources)
        } catch {
            return AudioThemeCatalog(
                themes: BuiltInAudioThemes.allFallbacks(),
                defaultThemeID: AudioTheme.sokobanID
            )
        }
    }

    static func loadStrict(from resources: any ContentResourceProvider) throws -> AudioThemeCatalog {
        let manifestData = try resources.data(at: AudioThemeManifestV1.resourcePath)
        let manifest = try AudioThemeFileCodec.decodeManifest(manifestData)

        var themes: [AudioTheme] = []
        var seenPaths = Set<String>()
        var seenIDs = Set<String>()
        var seenGames = Set<AudioGameMode>()

        for path in manifest.themes {
            guard !path.isEmpty else { throw AudioThemeDecodeError.emptyThemePath }
            guard seenPaths.insert(path).inserted else {
                throw AudioThemeDecodeError.duplicateThemePath(path)
            }

            let data = try resources.data(at: path)
            let theme: AudioTheme
            do {
                theme = try AudioThemeFileCodec.decodeTheme(data)
            } catch {
                let guessedID = (try? guessThemeID(from: data)) ?? path
                if AudioTheme.knownIDs.contains(guessedID) {
                    theme = BuiltInAudioThemes.fallback(id: guessedID)
                } else {
                    throw error
                }
            }

            guard seenIDs.insert(theme.id).inserted else {
                throw AudioThemeDecodeError.duplicateThemeID(theme.id)
            }
            guard seenGames.insert(theme.game).inserted else {
                throw AudioThemeDecodeError.duplicateGame(theme.game)
            }
            themes.append(theme)
        }

        guard !themes.isEmpty else {
            throw AudioThemeDecodeError.missingTheme(id: manifest.defaultThemeID)
        }
        guard themes.contains(where: { $0.id == manifest.defaultThemeID }) else {
            throw AudioThemeDecodeError.missingTheme(id: manifest.defaultThemeID)
        }

        for fallback in BuiltInAudioThemes.allFallbacks()
        where !themes.contains(where: { $0.id == fallback.id }) {
            if themes.contains(where: { $0.game == fallback.game }) {
                continue
            }
            themes.append(fallback)
        }

        return AudioThemeCatalog(themes: themes, defaultThemeID: manifest.defaultThemeID)
    }

    private static func guessThemeID(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = object["id"] as? String,
            !id.isEmpty
        else {
            return nil
        }
        return id
    }
}
