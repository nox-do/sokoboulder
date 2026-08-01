import GameCore
import SwiftUI

@main
struct MacGameApp: App {
    private enum ContentBootstrap {
        case ready(catalog: SokobanContentCatalog, progress: ProgressPersistence)
        case fault(message: String, progress: ProgressPersistence)
    }

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// App-wide run-file owner (Phase 2: one window → one writer generation stream).
    private let runPersistence = SokobanRunPersistence.makeDefault()
    /// Content and progress are created together so progress never receives a fake level ID.
    private let contentBootstrap: ContentBootstrap

    init() {
        do {
            let catalog = try BundleContentLoader.loadSokobanCatalog(
                from: Bundle(for: SokobanPlayController.self)
            )
            self.contentBootstrap = .ready(
                catalog: catalog,
                progress: ProgressPersistence.makeDefault(firstLevelID: catalog.first.id)
            )
        } catch {
            let message = "Failed to load game content: \(error)"
            self.contentBootstrap = .fault(
                message: message,
                progress: ProgressPersistence.unavailable(reason: message)
            )
        }
    }

    var body: some Scene {
        // Single-window scene: avoids concurrent writers on the same run file.
        Window("SokoBoulder", id: "main") {
            Group {
                switch contentBootstrap {
                case .ready(let catalog, let progress):
                    ContentView(
                        runPersistence: runPersistence,
                        progressPersistence: progress,
                        catalog: catalog
                    )
                case .fault(let message, let progress):
                    ContentView(
                        runPersistence: runPersistence,
                        progressPersistence: progress,
                        contentLoadFailureMessage: message
                    )
                }
            }
            .onAppear {
                appDelegate.attach(runPersistence: runPersistence)
            }
        }
        .commands {
            SokobanCommands()
        }
    }
}
