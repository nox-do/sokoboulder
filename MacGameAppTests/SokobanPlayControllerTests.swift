import CoreGraphics
import Testing
@testable import GameCore
@testable import MacGameApp

@Suite("SokobanPlayController app flow")
@MainActor
struct SokobanPlayControllerTests {
    private func makeController(holdAnimations: Bool = false) -> SokobanPlayController {
        let persistence = try! SokobanRunPersistence.ephemeral()
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: persistence
        )
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

    @Test("independent Return after awaiting choice restarts")
    func independentReturnRestarts() throws {
        let controller = makeController()
        completeDemoLevel(controller)
        awaitOutcomeChoice(controller)

        _ = controller.router.route(TestKeyEvent.keyUp(KeyCode.rightArrow))
        _ = controller.router.route(TestKeyEvent.keyUp(KeyCode.return))

        let before = try #require(controller.session).revision
        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.return))
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

        controller.startLevel()
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
