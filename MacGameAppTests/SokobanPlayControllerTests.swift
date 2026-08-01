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
            catalog: catalog
        )
        controller.dismissLevelIntro()
        controller.scene.holdAnimationsForTesting = holdAnimations
        return controller
    }

    private func completeDemoLevel(_ controller: SokobanPlayController) {
        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.rightArrow))
    }

    private func awaitOutcomeChoice(_ controller: SokobanPlayController) {
        controller.scene.settleAnimationsForTesting()
        if controller.presentationPhase == .outcomeAnimating {
            controller.skipOutcomePresentation()
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
            contentLoadFailureMessage: "Failed to load game content: missing manifest"
        )

        #expect(controller.presentationPhase == .faulted)
        #expect(controller.session == nil)
        #expect(controller.currentLevelID.isEmpty)
        #expect(progress.file.unlockedLevelIDs.isEmpty)
        #expect(controller.faultMessage == "Failed to load game content: missing manifest")
    }

    @Test("activation while paused bumps pause focus epoch")
    func activationWhilePausedRequestsResumeFocus() {
        let controller = makeController()
        controller.togglePause()
        #expect(controller.presentationPhase == .paused)
        let before = controller.pauseFocusEpoch
        controller.handleAppActivation()
        #expect(controller.pauseFocusEpoch == before + 1)
    }

    @Test("completed campaign progress without a run opens launch menu")
    func nonFreshProgressBootsToLaunchMenu() throws {
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
            catalog: catalog
        )

        #expect(controller.presentationPhase == .launchMenu)
        #expect(controller.session == nil)
    }

    @Test("non-fresh campaign with a saved run still opens launch menu")
    func nonFreshProgressWithRunBootsToLaunchMenu() async throws {
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
            catalog: catalog
        )
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
            catalog: catalog
        )
        #expect(relaunch.presentationPhase == .launchMenu)
        #expect(relaunch.session == nil)

        relaunch.continueCampaign()
        #expect(relaunch.session != nil)
        #expect(
            relaunch.presentationPhase == .playing
                || relaunch.presentationPhase == .outcomeAwaitingChoice
                || relaunch.presentationPhase == .levelIntro
        )
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
            catalog: catalog
        )
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
            )?.bestMoveCount == 1
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
        #expect(record?.bestMoveCount == 1)
        // Second terminal transition must run after undo cleared the session gate.
        #expect(controller.outcomeBestMoveCount == 1)
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
            catalog: catalog
        )
        controller.dismissLevelIntro()

        completeDemoLevel(controller)
        awaitOutcomeChoice(controller)
        controller.restartFromOutcomeOverlay()
        #expect(controller.presentationPhase == .playing)
        #expect(controller.outcomeBestMoveCount == nil)

        completeDemoLevel(controller)
        awaitOutcomeChoice(controller)
        #expect(controller.outcomeBestMoveCount == 1)
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
        #expect(
            controller.presentationPhase == .outcomeAnimating
                || controller.presentationPhase == .outcomeAwaitingChoice
        )
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

    @Test("focus loss opens pause while playing")
    func focusLossOpensPause() throws {
        let controller = makeController()
        controller.handleAppDeactivation()
        #expect(controller.presentationPhase == .paused)
        #expect(controller.session?.phase == .paused)
    }

    @Test("terminal move reaches settled revision before outcome awaiting choice")
    func terminalMoveSettlesBeforeOutcomeOverlay() throws {
        let controller = makeController(holdAnimations: true)
        controller.outcomePresentationTimeoutForTesting = 10

        completeDemoLevel(controller)
        #expect(controller.presentationPhase == .outcomeAnimating)
        let target = try #require(controller.session).revision
        #expect(controller.scene.appliedRevision == target)
        #expect(controller.scene.pendingAnimationCount > 0)
        #expect(controller.scene.settledRevision < target)

        controller.scene.settleAnimationsForTesting()
        #expect(controller.scene.settledRevision >= target)
        #expect(controller.presentationPhase == .outcomeAwaitingChoice)
    }

    @Test("Return during outcome animation skips only presentation")
    func returnDuringAnimationSkipsOnly() throws {
        let controller = makeController(holdAnimations: true)
        controller.outcomePresentationTimeoutForTesting = 10

        completeDemoLevel(controller)
        #expect(controller.presentationPhase == .outcomeAnimating)

        _ = controller.router.route(TestKeyEvent.keyUp(KeyCode.rightArrow))
        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.return))

        #expect(controller.presentationPhase == .outcomeAwaitingChoice)
        // Same held Return must not restart.
        #expect(controller.router.route(TestKeyEvent.keyDown(KeyCode.return)) == nil)
        #expect(controller.session?.phase == .outcomePresenting)
    }

    @Test("held confirm repeat is consumed after skipping outcome presentation")
    func heldConfirmRepeatIsConsumed() throws {
        let controller = makeController(holdAnimations: true)
        controller.outcomePresentationTimeoutForTesting = 10
        completeDemoLevel(controller)
        _ = controller.handleKeyEvent(TestKeyEvent.keyUp(KeyCode.rightArrow))

        #expect(controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.space)))
        #expect(controller.presentationPhase == .outcomeAwaitingChoice)
        let revision = try #require(controller.session).revision

        #expect(
            controller.handleKeyEvent(
                TestKeyEvent.keyDown(KeyCode.space, isARepeat: true)
            )
        )
        #expect(controller.session?.revision == revision)
        #expect(controller.session?.phase == .outcomePresenting)
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
        #expect(controller.scene.geometryForTesting.availableSize == CGSize(width: 500, height: 400))
    }

    @Test("HUD mirrors snapshot goal counters")
    func hudMirrorsGoalCounters() throws {
        let controller = makeController()
        #expect(controller.totalGoalCount == 1)
        #expect(controller.completedGoalCount == 0)
        completeDemoLevel(controller)
        awaitOutcomeChoice(controller)
        #expect(controller.completedGoalCount == 1)
        #expect(controller.moveCount == 1)
        #expect(controller.pushCount == 1)
    }

    @Test("deactivation during outcome clears locks without pausing")
    func deactivationDuringOutcome() throws {
        let controller = makeController(holdAnimations: true)
        controller.outcomePresentationTimeoutForTesting = 10
        completeDemoLevel(controller)
        #expect(controller.presentationPhase == .outcomeAnimating)
        #expect(controller.router.lockedKeyCodes.contains(KeyCode.rightArrow))

        controller.handleAppDeactivation()
        #expect(controller.session?.phase == .outcomePresenting)
        #expect(controller.presentationPhase == .outcomeAnimating)
        #expect(controller.router.lockedKeyCodes.isEmpty)
        #expect(controller.router.outcomeGateOpen)
    }

    @Test("new session resets scene revision stream before bootstrap")
    func newSessionResetsRevisionStream() throws {
        let controller = makeController(holdAnimations: true)
        controller.outcomePresentationTimeoutForTesting = 10
        completeDemoLevel(controller)
        controller.scene.settleAnimationsForTesting()
        #expect(controller.scene.settledRevision >= 2)

        controller.startLevel(showIntro: false)
        #expect(controller.scene.appliedRevision == 1)
        #expect(controller.scene.settledRevision == 1)
        #expect(controller.presentationPhase == .playing)

        controller.scene.holdAnimationsForTesting = true
        completeDemoLevel(controller)
        #expect(controller.presentationPhase == .outcomeAnimating)
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
