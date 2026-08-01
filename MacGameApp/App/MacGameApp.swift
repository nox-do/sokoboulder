import GameCore
import SwiftUI

@main
struct MacGameApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// App-wide run-file owner (Phase 2: one window → one writer generation stream).
    private let runPersistence = SokobanRunPersistence.makeDefault()

    var body: some Scene {
        // Single-window scene: avoids concurrent writers on the same run file.
        Window("SokoBoulder", id: "main") {
            ContentView(runPersistence: runPersistence)
                .onAppear {
                    appDelegate.attach(runPersistence: runPersistence)
                }
        }
        .commands {
            SokobanCommands()
        }
    }
}
