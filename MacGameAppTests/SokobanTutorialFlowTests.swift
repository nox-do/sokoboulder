import Foundation
import Testing

@testable import GameCore
@testable import MacGameApp

@Suite("Sokoban Step 9 tutorial flow")
@MainActor
struct SokobanTutorialFlowTests {
    private func makeController() -> SokobanPlayController {
        let persistence = try! SokobanRunPersistence.ephemeral()
        let catalog = try! BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        let progress = try! ProgressPersistence.ephemeral(firstLevelID: catalog.first.id)
        return SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: persistence,
            progressPersistence: progress,
            catalog: catalog,
            settingsStore: AppSettingsStore.ephemeral()
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
    func freshBootShowsIntro() throws {
        let controller = makeController()
        #expect(controller.presentationPhase == .levelIntro)
        #expect(controller.currentLevelID == "sokoban.tutorial.001")
        let level1 = try #require(controller.catalog.descriptor(id: "sokoban.tutorial.001"))
        #expect(controller.tutorialHintText == controller.catalog.tutorialHint(for: level1))
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
    func hintIDsResolve() throws {
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        for descriptor in catalog.levels {
            let text = catalog.tutorialHint(for: descriptor)
            #expect(text != descriptor.tutorialHintID)
            #expect(!text.isEmpty)
        }
    }

    @Test("levels 1 and 2 primary action advances; level 3 opens launch menu")
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
        #expect(
            controller.tutorialHintText
                == controller.catalog.tutorialHint(
                    for: try #require(controller.catalog.descriptor(id: "sokoban.tutorial.002"))
                ))
        controller.dismissLevelIntro()

        // Level 2 → next
        playMoves(controller, SokobanTutorialSolutions.level002)
        awaitOutcome(controller)
        #expect(controller.outcomePrimaryAction == .nextLevel(id: "sokoban.tutorial.003"))
        controller.performOutcomePrimaryAction()
        #expect(controller.currentLevelID == "sokoban.tutorial.003")
        controller.dismissLevelIntro()

        // Level 3 → Zurück to campaign overview
        playMoves(controller, SokobanTutorialSolutions.level003)
        awaitOutcome(controller)
        #expect(controller.outcomePrimaryAction == .openLaunchMenu)
        #expect(controller.outcomeTitle == AppStrings.text(.uiOutcomeTutorialComplete))
        #expect(controller.outcomePrimaryTitle == AppStrings.text(.uiOutcomeBack))
        controller.performOutcomePrimaryAction()
        #expect(controller.presentationPhase == .launchMenu)
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

    @Test("Return after celebration advances to the next level")
    func returnAfterCelebrationAdvances() throws {
        let controller = makeController()
        controller.dismissLevelIntro()
        playMoves(controller, SokobanTutorialSolutions.level001)
        awaitOutcome(controller)
        #expect(controller.focusedOutcomeAction == .primary)
        #expect(controller.outcomePrimaryAction == .nextLevel(id: "sokoban.tutorial.002"))

        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.return))
        #expect(controller.currentLevelID == "sokoban.tutorial.002")
        #expect(controller.presentationPhase == .levelIntro)
    }

    @Test("Escape on outcome performs primary action, not level selection")
    func escapeOnOutcomeAdvancesNotLevelSelect() throws {
        let controller = makeController()
        controller.dismissLevelIntro()
        playMoves(controller, SokobanTutorialSolutions.level001)
        awaitOutcome(controller)

        // Overlay Escape is wired to primary; exercise the same controller path.
        controller.performOutcomePrimaryAction()
        #expect(controller.currentLevelID == "sokoban.tutorial.002")
        #expect(controller.presentationPhase != .levelSelection)
        #expect(controller.presentationPhase != .launchMenu)
    }

    @Test("focus loss during intro resumes audio on activation")
    func introFocusLossResumesAudioOnActivation() {
        let spy = SpyAudioPlaybackBackend()
        let persistence = try! SokobanRunPersistence.ephemeral()
        let catalog = try! BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        let progress = try! ProgressPersistence.ephemeral(firstLevelID: catalog.first.id)
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: spy),
            runPersistence: persistence,
            progressPersistence: progress,
            catalog: catalog,
            settingsStore: AppSettingsStore.ephemeral()
        )
        #expect(controller.presentationPhase == .levelIntro)
        #expect(spy.musicStates.contains(.themeLoop))

        controller.handleAppDeactivation()
        #expect(controller.presentationPhase == .levelIntro)
        spy.resetCalls()

        controller.handleAppActivation()
        #expect(spy.musicStates.contains(.themeLoop))

        controller.dismissLevelIntro()
        spy.resetCalls()
        playMoves(controller, Array(SokobanTutorialSolutions.level001.prefix(2)))
        #expect(spy.playedEffects.contains(.cratePushed))
    }

    @Test("next level replaces the persisted run file")
    func nextLevelReplacesRunFile() async throws {
        let persistence = try SokobanRunPersistence.ephemeral()
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        let progress = try ProgressPersistence.ephemeral(firstLevelID: catalog.first.id)
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: persistence,
            progressPersistence: progress,
            catalog: catalog,
            settingsStore: AppSettingsStore.ephemeral()
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
