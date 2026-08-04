import Foundation
import Testing
@testable import MacGameApp

@Suite("Cave progress and level selection")
@MainActor
struct CaveProgressFlowTests {
    @Test("non-fresh cave opens launch menu; U unlocks locked levels")
    func caveHubAndCheatUnlock() throws {
        let bundle = Bundle(for: SokobanPlayController.self)
        let catalog = try BundleContentLoader.loadSokobanCatalog(from: bundle)
        let caveCatalog = try BundleContentLoader.loadCaveCatalog(from: bundle)
        let progress = try ProgressPersistence.ephemeral(
            firstLevelID: catalog.first.id,
            caveTutorialLevelIDs: caveCatalog.tutorialLevelIDs
        )
        _ = progress.recordCaveCompletion(
            levelID: "cave.demo.003",
            contentHash: caveCatalog.descriptor(id: "cave.demo.003")!.contentHash,
            ruleVersion: 1,
            score: 10,
            remainingTicks: 5,
            nextLevelID: "cave.demo.004"
        )

        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: try SokobanRunPersistence.ephemeral(),
            progressPersistence: progress,
            catalog: catalog,
            caveCatalog: caveCatalog,
            settingsStore: AppSettingsStore.ephemeral()
        )
        #expect(controller.presentationPhase == .gameSelection)
        controller.selectCaveFromGameSelection()
        #expect(controller.presentationPhase == .launchMenu)
        #expect(controller.shellCampaign == .cave)

        controller.openLevelSelection()
        #expect(controller.presentationPhase == .levelSelection)
        #expect(
            controller.levelSelectionRows.first { $0.id == "cave.demo.005" }?.availability
                == .locked
        )

        #expect(controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.u)))
        #expect(
            controller.levelSelectionRows.first { $0.id == "cave.demo.005" }?.availability
                != .locked
        )
        #expect(controller.gameplayNotice == AppStrings.text(.uiCheatLevelsUnlocked))
    }

    @Test("fresh cave starts first tutorial with all tutorials unlocked")
    func freshCaveStartsTutorial() throws {
        let bundle = Bundle(for: SokobanPlayController.self)
        let catalog = try BundleContentLoader.loadSokobanCatalog(from: bundle)
        let caveCatalog = try BundleContentLoader.loadCaveCatalog(from: bundle)
        let progress = try ProgressPersistence.ephemeral(
            firstLevelID: catalog.first.id,
            caveTutorialLevelIDs: caveCatalog.tutorialLevelIDs
        )
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: try SokobanRunPersistence.ephemeral(),
            progressPersistence: progress,
            catalog: catalog,
            caveCatalog: caveCatalog,
            settingsStore: AppSettingsStore.ephemeral()
        )
        controller.selectCaveFromGameSelection()
        #expect(controller.presentationPhase == .levelIntro)
        #expect(controller.currentLevelID == "cave.demo.001")
        #expect(progress.file.isCaveUnlocked("cave.demo.002"))
        #expect(progress.file.isCaveUnlocked("cave.demo.003"))
        #expect(!progress.file.isCaveUnlocked("cave.demo.004"))
    }

    @Test("cave hub help uses cave controls")
    func caveHubHelpIsModeAware() throws {
        let bundle = Bundle(for: SokobanPlayController.self)
        let catalog = try BundleContentLoader.loadSokobanCatalog(from: bundle)
        let caveCatalog = try BundleContentLoader.loadCaveCatalog(from: bundle)
        let progress = try ProgressPersistence.ephemeral(
            firstLevelID: catalog.first.id,
            caveTutorialLevelIDs: caveCatalog.tutorialLevelIDs
        )
        _ = progress.recordCaveCompletion(
            levelID: "cave.demo.003",
            contentHash: caveCatalog.descriptor(id: "cave.demo.003")!.contentHash,
            ruleVersion: 1,
            score: 10,
            remainingTicks: 5,
            nextLevelID: "cave.demo.004"
        )
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: try SokobanRunPersistence.ephemeral(),
            progressPersistence: progress,
            catalog: catalog,
            caveCatalog: caveCatalog,
            settingsStore: AppSettingsStore.ephemeral()
        )
        controller.selectCaveFromGameSelection()
        #expect(controller.presentationPhase == .launchMenu)
        controller.openHelpFromLaunchMenu()
        let help = controller.helpPresentation
        #expect(help.controls.contains { $0.id == "wait" })
        #expect(!help.controls.contains { $0.id == "undo_redo" })
        #expect(help.tutorialHints.isEmpty)
    }
}
