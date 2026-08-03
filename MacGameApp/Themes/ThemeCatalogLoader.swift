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

            let theme: VisualTheme
            var loadedData: Data?
            do {
                let data = try resources.data(at: path)
                loadedData = data
                let decoded = try ThemeFileCodec.decodeTheme(data)
                try verifyPixelTexturesIfNeeded(decoded, resources: resources)
                theme = decoded
            } catch {
                // Per-theme policy for known IDs; unknown IDs fail the catalog.
                let guessedID = guessThemeID(path: path, data: loadedData) ?? path
                if guessedID == VisualTheme.standardID {
                    theme = BuiltInThemes.standard
                } else if VisualTheme.optionalPixelIDs.contains(guessedID) {
                    // Optional pixel theme: skip rather than insert a duplicate standard.
                    continue
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

        return ThemeCatalog(themes: themes, defaultThemeID: manifest.defaultThemeID)
    }

    /// ``pixelInteger`` themes must reference existing bundle resources.
    private static func verifyPixelTexturesIfNeeded(
        _ theme: VisualTheme,
        resources: any ContentResourceProvider
    ) throws {
        guard theme.rendering.profile == .pixelInteger else { return }
        guard let textures = theme.rendering.textures else {
            throw ThemeDecodeError.missingTextures
        }
        for path in textures.allPaths {
            do {
                _ = try resources.data(at: path)
            } catch {
                throw ThemeDecodeError.missingTexture(path: path)
            }
        }
    }

    private static func guessThemeID(path: String, data: Data?) -> String? {
        if let data,
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = object["id"] as? String,
           !id.isEmpty
        {
            return id
        }
        // Basename without extension, e.g. Themes/theme.dungeon.json → theme.dungeon
        let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        return name.isEmpty ? nil : name
    }
}
