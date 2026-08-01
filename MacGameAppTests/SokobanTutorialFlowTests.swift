import Testing
@testable import GameCore
@testable import MacGameApp

@Suite("Sokoban Step 9 tutorial flow")
@MainActor
struct SokobanTutorialFlowTests {
    private func makeController() -> SokobanPlayController {
        let persistence = try! SokobanRunPersistence.ephemeral()
        return SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: persistence
        )
    }

    private func playMoves(_ controller: SokobanPlayController, _ moves: [Direction]) {
        for direction in moves {
            let key: UInt16
            switch direction {
            case .up: key = KeyCode.upArrow
            case .down: key = KeyCode.downArrow
            case .left: key = KeyCode.leftArrow
            case .right: key = KeyCode.rightArrow
            }
            controller.handleKeyEvent(TestKeyEvent.keyDown(key))
            _ = controller.router.route(TestKeyEvent.keyUp(key))
        }
    }

    private func awaitOutcome(_ controller: SokobanPlayController) {
        controller.scene.settleAnimationsForTesting()
        if controller.presentationPhase == .outcomeAnimating {
            controller.skipOutcomePresentation()
        }
        #expect(controller.presentationPhase == .outcomeAwaitingChoice)
    }

    @Test("fresh boot shows level intro with localized hint")
    func freshBootShowsIntro() {
        let controller = makeController()
        #expect(controller.presentationPhase == .levelIntro)
        #expect(controller.currentLevelID == "sokoban.tutorial.001")
        #expect(controller.tutorialHintText == AppStrings.text(.hintSokobanMoveAndPush))
        #expect(controller.router.mode == .levelIntro)

        // Moves are blocked until the intro is dismissed.
        let revision = controller.session?.revision
        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.rightArrow))
        #expect(controller.session?.revision == revision)

        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.return))
        #expect(controller.presentationPhase == .playing)
        #expect(controller.router.mode == .gameplay)
    }

    @Test("Escape dismisses the level intro")
    func escapeDismissesIntro() {
        let controller = makeController()
        #expect(controller.presentationPhase == .levelIntro)
        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.escape))
        #expect(controller.presentationPhase == .playing)
    }

    @Test("all tutorial hint IDs resolve to German copy")
    func hintIDsResolve() {
        for descriptor in SokobanLevelCatalog.tutorial {
            let text = AppStrings.text(id: descriptor.tutorialHintID)
            #expect(text != descriptor.tutorialHintID)
            #expect(!text.isEmpty)
        }
    }

    @Test("levels 1 and 2 primary action advances; level 3 returns to start")
    func outcomePrimaryActionsAcrossTutorial() throws {
        let controller = makeController()
        controller.dismissLevelIntro()

        // Level 1 → next
        playMoves(controller, SokobanTutorialSolutions.level001)
        awaitOutcome(controller)
        #expect(controller.outcomePrimaryAction == .nextLevel(id: "sokoban.tutorial.002"))
        #expect(controller.outcomePrimaryTitle == AppStrings.text(.uiOutcomeNextLevel))
        controller.performOutcomePrimaryAction()
        #expect(controller.currentLevelID == "sokoban.tutorial.002")
        #expect(controller.presentationPhase == .levelIntro)
        #expect(controller.tutorialHintText == AppStrings.text(.hintSokobanWalkAroundAndUndo))
        controller.dismissLevelIntro()

        // Level 2 → next
        playMoves(controller, SokobanTutorialSolutions.level002)
        awaitOutcome(controller)
        #expect(controller.outcomePrimaryAction == .nextLevel(id: "sokoban.tutorial.003"))
        controller.performOutcomePrimaryAction()
        #expect(controller.currentLevelID == "sokoban.tutorial.003")
        controller.dismissLevelIntro()

        // Level 3 → Zurück to tutorial start
        playMoves(controller, SokobanTutorialSolutions.level003)
        awaitOutcome(controller)
        #expect(controller.outcomePrimaryAction == .finishTutorial)
        #expect(controller.outcomeTitle == AppStrings.text(.uiOutcomeTutorialComplete))
        #expect(controller.outcomePrimaryTitle == AppStrings.text(.uiOutcomeBack))
        controller.performOutcomePrimaryAction()
        #expect(controller.currentLevelID == "sokoban.tutorial.001")
        #expect(controller.presentationPhase == .levelIntro)
        #expect(controller.moveCount == 0)
    }

    @Test("Return confirms the focused outcome button, not always primary")
    func returnHonorsFocusedOutcomeButton() throws {
        let controller = makeController()
        controller.dismissLevelIntro()
        playMoves(controller, SokobanTutorialSolutions.level001)
        awaitOutcome(controller)
        #expect(controller.outcomePrimaryAction == .nextLevel(id: "sokoban.tutorial.002"))

        controller.setFocusedOutcomeAction(.again)
        _ = controller.router.route(TestKeyEvent.keyUp(KeyCode.rightArrow))
        _ = controller.router.route(TestKeyEvent.keyUp(KeyCode.return))
        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.return))

        #expect(controller.currentLevelID == "sokoban.tutorial.001")
        #expect(controller.presentationPhase == .playing)
        #expect(controller.moveCount == 0)
    }

    @Test("focus loss during intro resumes audio on activation")
    func introFocusLossResumesAudioOnActivation() {
        let spy = SpyAudioPlaybackBackend()
        let persistence = try! SokobanRunPersistence.ephemeral()
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: spy),
            runPersistence: persistence
        )
        #expect(controller.presentationPhase == .levelIntro)
        #expect(spy.musicStates.contains(.sokobanLoop))

        controller.handleAppDeactivation()
        #expect(controller.presentationPhase == .levelIntro)
        spy.resetCalls()

        controller.handleAppActivation()
        #expect(spy.musicStates.contains(.sokobanLoop))

        controller.dismissLevelIntro()
        spy.resetCalls()
        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.rightArrow))
        #expect(spy.playedEffects.contains(.cratePushed))
    }

    @Test("next level replaces the persisted run file")
    func nextLevelReplacesRunFile() async throws {
        let persistence = try SokobanRunPersistence.ephemeral()
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: persistence
        )
        controller.dismissLevelIntro()
        playMoves(controller, SokobanTutorialSolutions.level001)
        awaitOutcome(controller)
        await persistence.flush()

        guard case .loaded(let before) = persistence.load() else {
            Issue.record("expected saved level-1 run")
            return
        }
        #expect(before.levelID == "sokoban.tutorial.001")

        controller.performOutcomePrimaryAction()
        controller.dismissLevelIntro()
        await persistence.flush()

        guard case .loaded(let after) = persistence.load() else {
            Issue.record("expected saved level-2 run")
            return
        }
        #expect(after.levelID == "sokoban.tutorial.002")
        #expect(after.cursor == 0)
        #expect(after.commands.isEmpty)
    }

    @Test("focus loss during intro does not open pause")
    func focusLossDuringIntroDoesNotPause() {
        let controller = makeController()
        #expect(controller.presentationPhase == .levelIntro)
        controller.handleAppDeactivation()
        #expect(controller.presentationPhase == .levelIntro)
        #expect(controller.session?.phase == .playing)
    }
}
