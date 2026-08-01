import AppKit

/// Application delegate for termination flush and Phase-2 single-window ownership.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var runPersistence: SokobanRunPersistence?

    func attach(runPersistence: SokobanRunPersistence) {
        self.runPersistence = runPersistence
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let runPersistence else {
            return .terminateNow
        }

        // Do not sync-write before flush: an older in-flight writer generation
        // could still overwrite that file. ``flush`` enqueues the cached DTO first.
        Task { @MainActor in
            await runPersistence.flush()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
