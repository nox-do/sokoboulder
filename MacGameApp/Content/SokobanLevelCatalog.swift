import Foundation
import GameCore

/// Built-in Sokoban tutorial catalog loaded from bundled JSON + manifest.
///
/// Prefer injecting ``SokobanContentCatalog`` into controllers. This facade
/// keeps existing call sites working against the default app/test bundle.
enum SokobanLevelCatalog {
    /// Lazily loads from the app/test bundle once. Fatally fails only when the
    /// suite cannot start; production paths should use ``BundleContentLoader``
    /// and surface ``ContentLoadError``.
    static let shared: SokobanContentCatalog = {
        do {
            return try BundleContentLoader.loadSokobanCatalog(
                from: Bundle(for: SokobanPlayController.self)
            )
        } catch {
            preconditionFailure("Bundled Sokoban content must load: \(error)")
        }
    }()

    static var tutorial: [SokobanLevelDescriptor] {
        shared.levels
    }

    static var first: SokobanLevelDescriptor {
        shared.first
    }

    static func descriptor(id: String) -> SokobanLevelDescriptor? {
        shared.descriptor(id: id)
    }

    static func index(of id: String) -> Int? {
        shared.index(of: id)
    }

    static func descriptor(after id: String) -> SokobanLevelDescriptor? {
        shared.descriptor(after: id)
    }

    static func title(for descriptor: SokobanLevelDescriptor) -> String {
        shared.title(for: descriptor)
    }

    static func tutorialHint(for descriptor: SokobanLevelDescriptor) -> String {
        shared.tutorialHint(for: descriptor)
    }
}
