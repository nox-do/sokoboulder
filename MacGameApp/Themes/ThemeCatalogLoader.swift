import Foundation

/// Ordered theme catalog with code fallbacks for known IDs.
struct ThemeCatalog: Equatable, Sendable {
    let themes: [VisualTheme]
    let defaultThemeID: String

    var selectableThemes: [VisualTheme] { themes }

    func theme(id: String) -> VisualTheme? {
        themes.first { $0.id == id }
    }

    func resolvedTheme(preferredID: String?) -> VisualTheme {
        if let preferredID, let theme = theme(id: preferredID) {
            return theme
        }
        if let theme = theme(id: defaultThemeID) {
            return theme
        }
        return BuiltInThemes.standard
    }
}

enum ThemeCatalogLoader {
    /// Loads themes from a resource provider. Falls back to built-ins on any catalog failure.
    static func load(from resources: any ContentResourceProvider) -> ThemeCatalog {
        do {
            return try loadStrict(from: resources)
        } catch {
            return ThemeCatalog(
                themes: BuiltInThemes.allFallbacks(),
                defaultThemeID: VisualTheme.standardID
            )
        }
    }

    static func loadStrict(from resources: any ContentResourceProvider) throws -> ThemeCatalog {
        let manifestData = try resources.data(at: ThemeManifestV1.resourcePath)
        let manifest = try ThemeFileCodec.decodeManifest(manifestData)

        var themes: [VisualTheme] = []
        var seenPaths = Set<String>()
        var seenIDs = Set<String>()

        for path in manifest.themes {
            guard !path.isEmpty else { throw ThemeDecodeError.emptyThemePath }
            guard seenPaths.insert(path).inserted else {
                throw ThemeDecodeError.duplicateThemePath(path)
            }

            let data = try resources.data(at: path)
            let theme: VisualTheme
            do {
                theme = try ThemeFileCodec.decodeTheme(data)
            } catch {
                // Per-theme fallback for known IDs; unknown IDs fail the catalog.
                let guessedID = (try? guessThemeID(from: data)) ?? path
                if VisualTheme.knownIDs.contains(guessedID) {
                    theme = BuiltInThemes.fallback(id: guessedID)
                } else {
                    throw error
                }
            }

            guard seenIDs.insert(theme.id).inserted else {
                throw ThemeDecodeError.duplicateThemeID(theme.id)
            }
            themes.append(theme)
        }

        guard !themes.isEmpty else {
            throw ThemeDecodeError.missingTheme(id: manifest.defaultThemeID)
        }
        guard themes.contains(where: { $0.id == manifest.defaultThemeID }) else {
            throw ThemeDecodeError.missingTheme(id: manifest.defaultThemeID)
        }

        // Ensure both shipping themes always remain selectable even if a JSON is broken
        // and was replaced by fallback above.
        for fallback in BuiltInThemes.allFallbacks()
        where !themes.contains(where: { $0.id == fallback.id }) {
            themes.append(fallback)
        }

        return ThemeCatalog(themes: themes, defaultThemeID: manifest.defaultThemeID)
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
