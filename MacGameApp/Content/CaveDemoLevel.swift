import Foundation
import GameCore

/// Compatibility helpers for tests that need the first bundled cave demo.
enum CaveDemoLevel {
    static let id = "cave.demo.001"

    static func makeLevel(
        from bundle: Bundle = Bundle(for: SokobanPlayController.self)
    ) throws -> CaveLevel {
        let catalog = try BundleContentLoader.loadCaveCatalog(from: bundle)
        guard let descriptor = catalog.descriptor(id: id) else {
            throw ContentLoadError.missingResource(path: id)
        }
        return descriptor.makeLevel()
    }
}
