import CoreGraphics
import Foundation
import Testing

@testable import GameCore
@testable import MacGameApp

@Suite("SokobanPlayController app flow")
@MainActor
struct SokobanPlayControllerTests {
    private func makeController(holdAnimations: Bool = false) -> SokobanPlayController {
        let persistence = try! SokobanRunPersistence.ephemeral()
        let catalog = try! BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        let progress = try! ProgressPersistence.ephemeral(firstLevelID: catalog.first.id)
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: persistence,
            progressPersistence: progress,
            catalog: catalog,
            settingsStore: AppSettingsStore.ephemeral()
        )
        if controller.presentationPhase == .gameSelection {
            controller.selectSokobanFromGameSelection()
        }
        controller.dismissLevelIntro()
        controller.scene.holdAnimationsForTesting = holdAnimations
        return controller
    }

    private func completeDemoLevel(_ controller: SokobanPlayController) {
        for (index, _) in SokobanTutorialSolutions.level001.enumerated() {
            controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.rightArrow))
            if index < SokobanTutorialSolutions.level001.count - 1 {
                controller.handleKeyEvent(TestKeyEvent.keyUp(KeyCode.rightArrow))
            }
        }
    }

    private func awaitOutcomeChoice(_ controller: SokobanPlayController) {
        if controller.presentationPhase != .outcomeAwaitingChoice {
            controller.showOutcomeOverlayNowForTesting()
        }
        #expect(controller.presentationPhase == .outcomeAwaitingChoice)
    }

    private func releaseOutcomeConfirmKeys(_ controller: SokobanPlayController) {
        _ = controller.router.route(TestKeyEvent.keyUp(KeyCode.rightArrow))
        _ = controller.router.route(TestKeyEvent.keyUp(KeyCode.return))
        _ = controller.router.route(TestKeyEvent.keyUp(KeyCode.space))
    }

    @Test("content bootstrap failure enters faulted UI without a synthetic level")
    func contentBootstrapFailureIsFaulted() throws {
        let progress = ProgressPersistence.unavailable(reason: "Content unavailable")
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: try SokobanRunPersistence.ephemeral(),
            progressPersistence: progress,
            contentLoadFailureMessage: "Failed to load game content: missing manifest",
            settingsStore: AppSettingsStore.ephemeral()
        )

        #expect(controller.presentationPhase == .faulted)
        #expect(controller.session == nil)
        #expect(controller.currentLevelID.isEmpty)
        #expect(progress.file.unlockedLevelIDs.isEmpty)
        #expect(controller.faultMessage == "Failed to load game content: missing manifest")
    }

    @Test("activation while paused resets pause focus to resume")
    func activationWhilePausedRequestsResumeFocus() {
        let controller = makeController()
        controller.togglePause()
        #expect(controller.presentationPhase == .paused)
        controller.setFocusedPauseAction(.settings)
        controller.handleAppActivation()
        #expect(controller.focusedPauseAction == .resume)
    }

    @Test("pause menu arrows and return are owned by the controller")
    func pauseMenuKeyboardOwnedByController() {
        let controller = makeController()
        controller.togglePause()
        #expect(controller.focusedPauseAction == .resume)

        #expect(controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.downArrow)))
        #expect(controller.focusedPauseAction == .restart)

        #expect(controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.return)))
        #expect(controller.presentationPhase == .playing)
    }

    @Test("game selection arrows skip disabled cave and activate Sokoban hub")
    func gameSelectionKeyboard() throws {
        let runPersistence = try SokobanRunPersistence.ephemeral()
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        let progress = try ProgressPersistence.ephemeral(firstLevelID: catalog.first.id)
        _ = progress.recordCompletion(
            levelID: catalog.first.id,
            contentHash: catalog.first.contentHash,
            ruleVersion: SokobanRules.ruleVersion,
            moveCount: 1,
            pushCount: 1,
            nextLevelID: catalog.descriptor(after: catalog.first.id)?.id
        )
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: runPersistence,
            progressPersistence: progress,
            catalog: catalog,
            settingsStore: AppSettingsStore.ephemeral()
        )
        #expect(controller.presentationPhase == .gameSelection)
        #expect(controller.focusedGameSelectionAction == .sokoban)
        #expect(controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.downArrow)))
        #expect(controller.focusedGameSelectionAction == .help)
        #expect(controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.upArrow)))
        #expect(controller.focusedGameSelectionAction == .sokoban)
        #expect(controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.return)))
        #expect(controller.presentationPhase == .launchMenu)
        #expect(controller.focusedLaunchAction == .continueCampaign)
        #expect(controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.downArrow)))
        #expect(controller.focusedLaunchAction == .selectLevel)
    }

    @Test("completed campaign progress without a run opens game selection")
    func nonFreshProgressBootsToGameSelection() throws {
        let runPersistence = try SokobanRunPersistence.ephemeral()
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        let progress = try ProgressPersistence.ephemeral(firstLevelID: catalog.first.id)
        _ = progress.recordCompletion(
            levelID: catalog.first.id,
            contentHash: catalog.first.contentHash,
            ruleVersion: SokobanRules.ruleVersion,
            moveCount: 1,
            pushCount: 1,
            nextLevelID: catalog.descriptor(after: catalog.first.id)?.id
        )

        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: runPersistence,
            progressPersistence: progress,
            catalog: catalog,
            settingsStore: AppSettingsStore.ephemeral()
        )

        #expect(controller.presentationPhase == .gameSelection)
        #expect(controller.session == nil)
        controller.selectSokobanFromGameSelection()
        #expect(controller.presentationPhase == .launchMenu)
    }

    @Test("launch menu reset clears progress and restarts tutorial 1")
    func resetCampaignProgressFromLaunchMenu() throws {
        let runPersistence = try SokobanRunPersistence.ephemeral()
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        let progress = try ProgressPersistence.ephemeral(firstLevelID: catalog.first.id)
        _ = progress.recordCompletion(
            levelID: catalog.first.id,
            contentHash: catalog.first.contentHash,
            ruleVersion: SokobanRules.ruleVersion,
            moveCount: 1,
            pushCount: 1,
            nextLevelID: catalog.descriptor(after: catalog.first.id)?.id
        )
        progress.markHintSeen("hint.already.seen")

        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: runPersistence,
            progressPersistence: progress,
            catalog: catalog,
            settingsStore: AppSettingsStore.ephemeral()
        )
        controller.selectSokobanFromGameSelection()
        #expect(controller.presentationPhase == .launchMenu)
        #expect(!progress.file.isFreshCampaign)

        controller.resetCampaignProgressFromLaunchMenu()

        #expect(progress.file.isFreshCampaign)
        #expect(progress.file.seenTutorialHintIDs.isEmpty)
        #expect(progress.file.completedLevelIDs.isEmpty)
        #expect(controller.currentLevelID == catalog.first.id)
        #expect(controller.presentationPhase == .levelIntro)
        if case .absent = runPersistence.load() {
            // expected: run file removed
        } else {
            Issue.record("expected run file to be absent after reset")
        }
    }

    @Test("non-fresh campaign with a saved run still opens game selection")
    func nonFreshProgressWithRunBootsToGameSelection() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SokoBoulder-launch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let runPersistence = SokobanRunPersistence(
            configuration: SokobanRunStoreConfiguration(
                directoryURL: directory,
                fileName: SokobanRunStoreConfiguration.defaultFileName
            )
        )
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        let progress = try ProgressPersistence.ephemeral(
            directoryURL: directory,
            firstLevelID: catalog.first.id
        )

        let priming = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: runPersistence,
            progressPersistence: progress,
            catalog: catalog,
            settingsStore: AppSettingsStore.ephemeral()
        )
        priming.selectSokobanFromGameSelection()
        priming.dismissLevelIntro()
        completeDemoLevel(priming)
        awaitOutcomeChoice(priming)
        await runPersistence.flush()
        #expect(runPersistence.load() != .absent)

        // Reload progress from disk so the second controller sees the same campaign state.
        let reloadedProgress = ProgressPersistence(
            configuration: ProgressPersistence.Configuration(
                directoryURL: directory,
                fileName: ProgressPersistence.Configuration.defaultFileName
            ),
            firstLevelID: catalog.first.id
        )
        #expect(!reloadedProgress.file.isFreshCampaign)

        let relaunch = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: runPersistence,
            progressPersistence: reloadedProgress,
            catalog: catalog,
            settingsStore: AppSettingsStore.ephemeral()
        )
        #expect(relaunch.presentationPhase == .gameSelection)
        #expect(relaunch.session == nil)

        relaunch.selectSokobanFromGameSelection()
        #expect(relaunch.presentationPhase == .launchMenu)
        relaunch.continueCampaign()
        #expect(relaunch.session != nil)
        #expect(
            relaunch.presentationPhase == .playing
                || relaunch.presentationPhase == .outcomeAwaitingChoice
                || relaunch.presentationPhase == .levelIntro
        )
    }

    @Test("run from a known superseded tutorial layout restarts without recovery")
    func supersededTutorialRunRestarts() async throws {
        let runPersistence = try SokobanRunPersistence.ephemeral()
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        let progress = try ProgressPersistence.ephemeral(firstLevelID: catalog.first.id)
        let oldRun = SokobanRunFileV1(
            schemaVersion: SokobanRunFileV1.currentSchemaVersion,
            levelID: catalog.first.id,
            contentHash: "d951ac0c0b9114dae245aecabc5befdac913614a096a21f3fd303f0777cfd594",
            ruleVersion: SokobanRules.ruleVersion,
            checkpoint: SokobanCheckpointV1(
                schemaVersion: SokobanCheckpointV1.currentSchemaVersion,
                playerColumn: 1,
                playerRow: 1,
                crates: [SokobanCratePlacementV1(id: 2, column: 3, row: 1)],
                moveCount: 0,
                pushCount: 0,
                status: .playing
            ),
            commands: [.right],
            cursor: 1
        )
        runPersistence.scheduleSave(oldRun)
        await runPersistence.flush()

        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: runPersistence,
            progressPersistence: progress,
            catalog: catalog,
            settingsStore: AppSettingsStore.ephemeral()
        )

        #expect(controller.presentationPhase == .levelIntro)
        #expect(controller.recoveryMessage == nil)
        #expect(controller.scene.currentSnapshot?.player.position == GridPosition(column: 2, row: 2))
        #expect(controller.scene.currentSnapshot?.entities.first?.position == GridPosition(column: 4, row: 2))
        #expect(
            controller.scene.currentSnapshot?.cell(at: GridPosition(column: 6, row: 2))?.terrain
                == .goal
        )

        await runPersistence.flush()
        guard case .loaded(let migrated) = runPersistence.load() else {
            Issue.record("expected migrated run")
            return
        }
        #expect(migrated.contentHash == catalog.first.contentHash)
        #expect(migrated.commands.isEmpty)
    }

    @Test("better second completion after undo updates records")
    func betterCompletionAfterUndoUpdatesRecords() throws {
        let runPersistence = try SokobanRunPersistence.ephemeral()
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        let progress = try ProgressPersistence.ephemeral(firstLevelID: catalog.first.id)
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: runPersistence,
            progressPersistence: progress,
            catalog: catalog,
            settingsStore: AppSettingsStore.ephemeral()
        )
        controller.selectSokobanFromGameSelection()
        controller.dismissLevelIntro()

        completeDemoLevel(controller)
        awaitOutcomeChoice(controller)
        #expect(controller.outcomeNewBestMoves)
        #expect(controller.outcomeNewBestPushes)
        #expect(
            progress.file.record(
                levelID: catalog.first.id,
                contentHash: catalog.first.contentHash,
                ruleVersion: SokobanRules.ruleVersion
            )?.bestMoveCount == 3
        )

        controller.undoFromOutcomeOverlay()
        #expect(controller.presentationPhase == .playing)
        #expect(controller.outcomeNewBestMoves == false)
        #expect(controller.outcomeBestMoveCount == nil)

        completeDemoLevel(controller)
        awaitOutcomeChoice(controller)

        let record = progress.file.record(
            levelID: catalog.first.id,
            contentHash: catalog.first.contentHash,
            ruleVersion: SokobanRules.ruleVersion
        )
        #expect(record?.bestMoveCount == 3)
        // Second terminal transition must run after undo cleared the session gate.
        #expect(controller.outcomeBestMoveCount == 3)
        #expect(controller.outcomeNewBestMoves == false)
    }

    @Test("better completion after restart updates records")
    func betterCompletionAfterRestartUpdatesRecords() throws {
        let runPersistence = try SokobanRunPersistence.ephemeral()
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        let progress = try ProgressPersistence.ephemeral(firstLevelID: catalog.first.id)
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: runPersistence,
            progressPersistence: progress,
            catalog: catalog,
            settingsStore: AppSettingsStore.ephemeral()
        )
        controller.selectSokobanFromGameSelection()
        controller.dismissLevelIntro()

        completeDemoLevel(controller)
        awaitOutcomeChoice(controller)
        controller.restartFromOutcomeOverlay()
        #expect(controller.presentationPhase == .playing)
        #expect(controller.outcomeBestMoveCount == nil)

        completeDemoLevel(controller)
        awaitOutcomeChoice(controller)
        #expect(controller.outcomeBestMoveCount == 3)
    }

    @Test("next level updates lastSelectedLevelID")
    func nextLevelUpdatesLastSelected() throws {
        let controller = makeController()
        completeDemoLevel(controller)
        awaitOutcomeChoice(controller)
        releaseOutcomeConfirmKeys(controller)
        controller.performOutcomePrimaryAction()

        #expect(controller.currentLevelID == "sokoban.tutorial.002")
        #expect(
            controller.progressPersistence.file.lastSelectedLevelID
                == "sokoban.tutorial.002"
        )
    }

    @Test("undo and redo use the shared controller/session API")
    func sharedUndoRedoAPI() throws {
        let controller = makeController()
        #expect(controller.canUndo == false)
        #expect(controller.canRedo == false)

        completeDemoLevel(controller)
        awaitOutcomeChoice(controller)
        #expect(controller.canUndo)
        #expect(controller.canRedo == false)

        controller.undo()
        #expect(controller.presentationPhase == .playing)
        #expect(controller.canRedo)
        #expect(controller.session?.phase == .playing)

        controller.redo()
        awaitOutcomeChoice(controller)
    }

    @Test("pause overlay path stops gameplay input")
    func pauseStopsGameplayInput() throws {
        let controller = makeController()
        controller.togglePause()
        #expect(controller.presentationPhase == .paused)
        #expect(controller.session?.phase == .paused)
        #expect(controller.router.mode == .paused)

        #expect(controller.router.route(TestKeyEvent.keyDown(KeyCode.rightArrow)) == nil)
        let revision = try #require(controller.session).revision
        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.rightArrow))
        #expect(controller.session?.revision == revision)
    }

    @Test("Escape while paused returns to game selection")
    func escapeFromPauseOpensGameSelection() throws {
        let controller = makeController()
        controller.togglePause()
        #expect(controller.presentationPhase == .paused)

        #expect(controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.escape)))
        #expect(controller.presentationPhase == .gameSelection)
        #expect(controller.session == nil)
        #expect(controller.router.mode == .modalBlocked)
    }

    @Test("pause Spielauswahl button returns to game selection")
    func pauseLevelSelectOpensGameSelection() throws {
        let controller = makeController()
        controller.togglePause()
        controller.openLevelSelectionFromPauseOverlay()
        #expect(controller.presentationPhase == .gameSelection)
        #expect(controller.session == nil)
    }

    @Test("focus loss opens pause while playing")
    func focusLossOpensPause() throws {
        let controller = makeController()
        controller.handleAppDeactivation()
        #expect(controller.presentationPhase == .paused)
        #expect(controller.session?.phase == .paused)
    }

    @Test("terminal move delays the outcome overlay")
    func terminalMoveDelaysOutcomeOverlay() throws {
        let controller = makeController(holdAnimations: true)

        completeDemoLevel(controller)
        #expect(controller.presentationPhase == .playing)
        #expect(controller.session?.phase == .outcomePresenting)
        let target = try #require(controller.session).revision
        #expect(controller.scene.appliedRevision == target)
        #expect(controller.scene.pendingAnimationCount > 0)

        controller.showOutcomeOverlayNowForTesting()
        #expect(controller.presentationPhase == .outcomeAwaitingChoice)
    }

    @Test("held confirm after delay opens overlay without advancing on repeat")
    func heldConfirmRepeatIsConsumed() throws {
        let controller = makeController(holdAnimations: true)
        completeDemoLevel(controller)
        _ = controller.handleKeyEvent(TestKeyEvent.keyUp(KeyCode.rightArrow))
        controller.showOutcomeOverlayNowForTesting()
        #expect(controller.presentationPhase == .outcomeAwaitingChoice)

        #expect(controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.space)))
        #expect(controller.currentLevelID == "sokoban.tutorial.002")
        let revision = try #require(controller.session).revision

        #expect(
            controller.handleKeyEvent(
                TestKeyEvent.keyDown(KeyCode.space, isARepeat: true)
            )
        )
        #expect(controller.session?.revision == revision)
    }

    @Test("independent Return after awaiting choice advances to next level")
    func independentReturnAdvancesLevel() throws {
        let controller = makeController()
        completeDemoLevel(controller)
        awaitOutcomeChoice(controller)
        #expect(controller.outcomePrimaryAction == .nextLevel(id: "sokoban.tutorial.002"))

        releaseOutcomeConfirmKeys(controller)

        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.return))
        #expect(controller.currentLevelID == "sokoban.tutorial.002")
        #expect(controller.presentationPhase == .levelIntro)
        #expect(controller.levelTitle == "Umweg und Undo")
    }

    @Test("play again from outcome restarts the same level")
    func playAgainRestartsSameLevel() throws {
        let controller = makeController()
        completeDemoLevel(controller)
        awaitOutcomeChoice(controller)

        let before = try #require(controller.session).revision
        controller.restartFromOutcomeOverlay()
        #expect(controller.currentLevelID == "sokoban.tutorial.001")
        #expect(controller.presentationPhase == .playing)
        #expect(controller.session?.phase == .playing)
        #expect(try #require(controller.session).revision > before)
    }

    @Test("undo from outcome returns to playing")
    func undoFromOutcomeReturnsPlaying() throws {
        let controller = makeController()
        completeDemoLevel(controller)
        awaitOutcomeChoice(controller)

        controller.undo()
        #expect(controller.presentationPhase == .playing)
        #expect(controller.session?.phase == .playing)
        #expect(controller.router.mode == .gameplay)
    }

    @Test("restart from pause hard-resyncs")
    func restartFromPauseHardResync() throws {
        let controller = makeController()
        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.leftArrow))
        controller.togglePause()
        #expect(controller.presentationPhase == .paused)

        let before = try #require(controller.session).revision
        controller.restart()
        #expect(controller.presentationPhase == .playing)
        #expect(controller.session?.phase == .playing)
        #expect(try #require(controller.session).revision > before)
        #expect(controller.scene.currentSnapshot?.moveCount == 0)
    }

    @Test("resize during pause and outcome stays consistent")
    func resizeDuringPauseAndOutcome() throws {
        let controller = makeController()
        controller.togglePause()
        let pausedRevision = try #require(controller.session).revision
        controller.scene.resize(to: CGSize(width: 800, height: 600))
        #expect(controller.session?.revision == pausedRevision)
        #expect(controller.presentationPhase == .paused)

        controller.resumeFromPauseOverlay()
        completeDemoLevel(controller)
        awaitOutcomeChoice(controller)
        let outcomeRevision = try #require(controller.session).revision
        controller.scene.resize(to: CGSize(width: 500, height: 400))
        #expect(controller.session?.revision == outcomeRevision)
        #expect(controller.presentationPhase == .outcomeAwaitingChoice)
        #expect(
            controller.scene.geometryForTesting.availableSize == CGSize(width: 500, height: 400))
    }

    @Test("HUD mirrors snapshot goal counters")
    func hudMirrorsGoalCounters() throws {
        let controller = makeController()
        #expect(controller.totalGoalCount == 1)
        #expect(controller.completedGoalCount == 0)
        completeDemoLevel(controller)
        awaitOutcomeChoice(controller)
        #expect(controller.completedGoalCount == 1)
        #expect(controller.moveCount == 3)
        #expect(controller.pushCount == 2)
    }

    @Test("deactivation during outcome clears locks without pausing")
    func deactivationDuringOutcome() throws {
        let controller = makeController(holdAnimations: true)
        completeDemoLevel(controller)
        #expect(controller.session?.phase == .outcomePresenting)
        #expect(controller.router.lockedKeyCodes.contains(KeyCode.rightArrow))

        controller.handleAppDeactivation()
        #expect(controller.session?.phase == .outcomePresenting)
        #expect(controller.presentationPhase == .playing)
        #expect(controller.router.lockedKeyCodes.isEmpty)
        #expect(controller.router.outcomeGateOpen)
    }

    @Test("new session resets scene revision stream before bootstrap")
    func newSessionResetsRevisionStream() throws {
        let controller = makeController(holdAnimations: true)
        completeDemoLevel(controller)
        controller.scene.settleAnimationsForTesting()
        controller.showOutcomeOverlayNowForTesting()
        #expect(controller.scene.settledRevision >= 2)

        controller.startLevel(showIntro: false)
        #expect(controller.scene.appliedRevision == 1)
        #expect(controller.scene.settledRevision == 1)
        #expect(controller.presentationPhase == .playing)

        controller.scene.holdAnimationsForTesting = true
        completeDemoLevel(controller)
        #expect(controller.session?.phase == .outcomePresenting)
        let target = try #require(controller.session).revision
        #expect(controller.scene.settledRevision < target)
    }

    @Test("in-session restart continues the revision stream")
    func inSessionRestartKeepsRevisionStream() throws {
        let controller = makeController()
        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.leftArrow))
        let afterMove = try #require(controller.session).revision
        #expect(afterMove >= 2)

        controller.restart()
        #expect(try #require(controller.session).revision == afterMove + 1)
        #expect(controller.scene.appliedRevision == afterMove + 1)
        #expect(controller.scene.settledRevision == afterMove + 1)
        #expect(controller.presentationPhase == .playing)
    }
}
