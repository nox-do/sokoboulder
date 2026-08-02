import Foundation
@testable import MacGameApp

/// Shared factory for Phase 3 controller tests (isolated settings + manual timers).
@MainActor
enum TestPlayControllerFactory {
    struct Harness {
        let controller: SokobanPlayController
        let settings: AppSettingsStore
        let scheduler: ManualDelayedActionScheduler
        let assistive: ManualAssistiveReadingProbe
        let reduceMotion: ManualReduceMotionSource
        let progress: ProgressPersistence
        let runPersistence: SokobanRunPersistence
        let catalog: SokobanContentCatalog
    }

    static func make(
        audioDirector: AudioDirector = AudioDirector(backend: NoOpAudioPlaybackBackend()),
        markIntroDismissed: Bool = false,
        assistivePreventsAutoDismiss: Bool = false,
        systemReduceMotion: Bool = false
    ) throws -> Harness {
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Foundation.Bundle(for: SokobanPlayController.self)
        )
        let runPersistence = try SokobanRunPersistence.ephemeral()
        let progress = try ProgressPersistence.ephemeral(firstLevelID: catalog.first.id)
        let settings = AppSettingsStore.ephemeral()
        let scheduler = ManualDelayedActionScheduler()
        let assistive = ManualAssistiveReadingProbe(
            preventsIntroAutoDismiss: assistivePreventsAutoDismiss
        )
        let reduceMotion = ManualReduceMotionSource(
            systemReduceMotionEnabled: systemReduceMotion
        )
        let controller = SokobanPlayController(
            audioDirector: audioDirector,
            runPersistence: runPersistence,
            progressPersistence: progress,
            catalog: catalog,
            settingsStore: settings,
            reduceMotionSource: reduceMotion,
            assistiveReadingProbe: assistive,
            delayedActionScheduler: scheduler
        )
        reduceMotion.onChange = { [weak controller] in
            controller?.reduceMotionProvider.refresh()
        }
        if markIntroDismissed, controller.presentationPhase == .levelIntro {
            controller.dismissLevelIntro()
        }
        return Harness(
            controller: controller,
            settings: settings,
            scheduler: scheduler,
            assistive: assistive,
            reduceMotion: reduceMotion,
            progress: progress,
            runPersistence: runPersistence,
            catalog: catalog
        )
    }
}
