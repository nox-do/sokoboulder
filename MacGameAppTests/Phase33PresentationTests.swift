import Combine
import AppKit
import Foundation
import Testing
@testable import GameCore
@testable import MacGameApp

@Suite("Phase 3.3 presentation platform")
@MainActor
struct Phase33PresentationTests {
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

    @Test("1 unseen tutorial hint appears on fresh start")
    func unseenHintAppears() throws {
        let bundle = try TestPlayControllerFactory.make()
        #expect(bundle.controller.presentationPhase == .levelIntro)
        let level1 = try #require(bundle.catalog.descriptor(id: "sokoban.tutorial.001"))
        #expect(bundle.controller.tutorialHintText == bundle.catalog.tutorialHint(for: level1))
        #expect(bundle.scheduler.pendingCount == 1)
    }

    @Test("2 intro auto-dismisses after scheduled delay")
    func introAutoDismisses() throws {
        let bundle = try TestPlayControllerFactory.make()
        #expect(bundle.controller.presentationPhase == .levelIntro)
        bundle.scheduler.fireNext()
        #expect(bundle.controller.presentationPhase == .playing)
        let hintID = try #require(
            bundle.catalog.descriptor(id: "sokoban.tutorial.001")?.tutorialHintID
        )
        #expect(bundle.progress.file.hasSeenHint(hintID))
    }

    @Test("3 manual dismiss cancels the intro timer")
    func manualDismissCancelsTimer() throws {
        let bundle = try TestPlayControllerFactory.make()
        bundle.controller.dismissLevelIntro()
        #expect(bundle.controller.presentationPhase == .playing)
        #expect(bundle.scheduler.pendingCount == 0)
        bundle.scheduler.fireNext()
        #expect(bundle.controller.presentationPhase == .playing)
    }

    @Test("4 stale intro timer cannot close a later overlay or level")
    func staleTimerDoesNotAffectLaterLevel() throws {
        let bundle = try TestPlayControllerFactory.make()
        #expect(bundle.scheduler.pendingCount == 1)
        // Start next level while first intro timer is still pending (cancel + new gen).
        bundle.controller.startSelectedLevel(id: "sokoban.tutorial.001", showIntro: false)
        #expect(bundle.controller.presentationPhase == .playing)
        // Fire any leftover cancelled work — must not change phase.
        bundle.scheduler.fireNext()
        #expect(bundle.controller.presentationPhase == .playing)

        bundle.controller.startLevel(id: "sokoban.tutorial.002", showIntro: true)
        #expect(bundle.controller.presentationPhase == .levelIntro)
        let pendingBefore = bundle.scheduler.pendingCount
        #expect(pendingBefore == 1)
        bundle.controller.dismissLevelIntro()
        bundle.scheduler.fireNext()
        #expect(bundle.controller.presentationPhase == .playing)
    }

    @Test("5 seen hint is skipped on normal level start")
    func seenHintSkipped() throws {
        let bundle = try TestPlayControllerFactory.make()
        let hintID = try #require(
            bundle.catalog.descriptor(id: "sokoban.tutorial.001")?.tutorialHintID
        )
        bundle.controller.dismissLevelIntro()
        #expect(bundle.progress.file.hasSeenHint(hintID))

        bundle.controller.startLevel(id: "sokoban.tutorial.001")
        #expect(bundle.controller.presentationPhase == .playing)
        #expect(bundle.scheduler.pendingCount == 0)
    }

    @Test("6 assistive reading prevents intro auto-dismiss")
    func assistivePreventsAutoDismiss() throws {
        let bundle = try TestPlayControllerFactory.make(assistivePreventsAutoDismiss: true)
        #expect(bundle.controller.presentationPhase == .levelIntro)
        #expect(bundle.scheduler.pendingCount == 0)
        #expect(bundle.controller.levelIntroPresentation.autoDismissDelay == nil)
    }

    @Test("6b enabling assistive reading blocks a pending auto-dismiss")
    func assistiveChangePreventsPendingAutoDismiss() throws {
        let bundle = try TestPlayControllerFactory.make()
        let hintID = try #require(
            bundle.catalog.descriptor(id: "sokoban.tutorial.001")?.tutorialHintID
        )
        #expect(bundle.scheduler.pendingCount == 1)

        bundle.assistive.preventsIntroAutoDismiss = true
        bundle.scheduler.fireNext()

        #expect(bundle.controller.presentationPhase == .levelIntro)
        #expect(!bundle.progress.file.hasSeenHint(hintID))
        #expect(bundle.scheduler.pendingCount == 0)
    }

    @Test("6c inactive app suspends intro auto-dismiss until activation")
    func inactiveAppSuspendsIntroAutoDismiss() throws {
        let spy = SpyAudioPlaybackBackend()
        let bundle = try TestPlayControllerFactory.make(
            audioDirector: AudioDirector(backend: spy)
        )
        let hintID = try #require(
            bundle.catalog.descriptor(id: "sokoban.tutorial.001")?.tutorialHintID
        )
        spy.resetCalls()

        bundle.controller.handleAppDeactivation()
        #expect(bundle.scheduler.pendingCount == 0)
        bundle.scheduler.fireNext()
        #expect(bundle.controller.presentationPhase == .levelIntro)
        #expect(!bundle.progress.file.hasSeenHint(hintID))
        #expect(spy.musicStates.last == .stopped)

        bundle.controller.handleAppActivation()
        #expect(bundle.scheduler.pendingCount == 1)
        #expect(spy.musicStates.last == .sokobanLoop)

        bundle.scheduler.fireNext()
        #expect(bundle.controller.presentationPhase == .playing)
        #expect(bundle.progress.file.hasSeenHint(hintID))
    }

    @Test("7 help still lists already-seen tutorial hints")
    func helpShowsSeenHints() throws {
        let bundle = try TestPlayControllerFactory.make(markIntroDismissed: true)
        let hintID = try #require(
            bundle.catalog.descriptor(id: "sokoban.tutorial.001")?.tutorialHintID
        )
        #expect(bundle.progress.file.hasSeenHint(hintID))

        // Reach launch menu via non-fresh progress path.
        _ = bundle.progress.recordCompletion(
            levelID: "sokoban.tutorial.001",
            contentHash: bundle.catalog.first.contentHash,
            ruleVersion: SokobanRules.ruleVersion,
            moveCount: 1,
            pushCount: 1,
            nextLevelID: "sokoban.tutorial.002"
        )
        bundle.controller.openLaunchMenu()
        bundle.controller.openHelpFromLaunchMenu()
        let help = bundle.controller.helpPresentation
        #expect(help.tutorialHints.contains { $0.id == hintID })
        #expect(help.tutorialHints.count == bundle.catalog.levels.count)
    }

    @Test("8 help and settings return to the correct origin")
    func helpAndSettingsReturnToOrigin() throws {
        let bundle = try TestPlayControllerFactory.make(markIntroDismissed: true)
        bundle.controller.openLaunchMenu()
        #expect(bundle.controller.session == nil)

        bundle.controller.openHelpFromLaunchMenu()
        #expect(bundle.controller.presentationPhase == .help)
        #expect(bundle.controller.overlayReturnOrigin == .launchMenu)
        bundle.controller.dismissHelpOrSettings()
        #expect(bundle.controller.presentationPhase == .launchMenu)

        bundle.controller.openSettingsFromLaunchMenu()
        #expect(bundle.controller.presentationPhase == .settings)
        bundle.controller.dismissHelpOrSettings()
        #expect(bundle.controller.presentationPhase == .launchMenu)
    }

    @Test("9 pause keeps the session while help or settings are open")
    func pauseKeepsSessionThroughHelpSettings() throws {
        let bundle = try TestPlayControllerFactory.make(markIntroDismissed: true)
        let session = try #require(bundle.controller.session)
        let revision = session.revision

        bundle.controller.togglePause()
        #expect(bundle.controller.presentationPhase == .paused)
        #expect(bundle.controller.session === session)

        bundle.controller.openHelpFromPause()
        #expect(bundle.controller.presentationPhase == .help)
        #expect(bundle.controller.session === session)
        #expect(bundle.controller.session?.phase == .paused)
        #expect(bundle.controller.router.mode == .modalBlocked)
        #expect(bundle.controller.session?.revision == revision)
        #expect(!bundle.controller.canUndo)
        #expect(!bundle.controller.canRedo)
        #expect(!bundle.controller.canRestart)
        #expect(!bundle.controller.canResume)

        bundle.controller.dismissHelpOrSettings()
        #expect(bundle.controller.presentationPhase == .paused)
        #expect(bundle.controller.session === session)
        #expect(bundle.controller.canResume)

        bundle.controller.openSettingsFromPause()
        #expect(bundle.controller.presentationPhase == .settings)
        #expect(bundle.controller.session === session)
        #expect(!bundle.controller.canUndo)
        #expect(!bundle.controller.canRestart)
        bundle.controller.dismissHelpOrSettings()
        #expect(bundle.controller.presentationPhase == .paused)
        #expect(bundle.controller.session?.revision == revision)
    }

    @Test("10 settings persist across store reloads")
    func settingsPersist() throws {
        let name = "\(AppSettingsStore.suitePrefix).persist.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        let first = AppSettingsStore(defaults: defaults)
        first.reduceMotionEnabled = true
        first.musicVolume = 0.35
        first.effectsVolume = 0.55
        first.isMuted = true

        let second = AppSettingsStore(defaults: defaults)
        #expect(second.reduceMotionEnabled == true)
        #expect(second.musicVolume == 0.35)
        #expect(second.effectsVolume == 0.55)
        #expect(second.isMuted == true)
        defaults.removePersistentDomain(forName: name)
    }

    @Test("11 volumes are clamped and applied live")
    func volumesClampedAndLive() throws {
        let spy = SpyAudioPlaybackBackend()
        let bundle = try TestPlayControllerFactory.make(
            audioDirector: AudioDirector(backend: spy),
            markIntroDismissed: true
        )
        bundle.controller.updateMusicVolume(2.5)
        #expect(bundle.settings.musicVolume == 1)
        #expect(spy.lastOutputSettings?.musicVolume == 1)

        bundle.controller.updateEffectsVolume(-0.2)
        #expect(bundle.settings.effectsVolume == 0)
        #expect(spy.lastOutputSettings?.effectsVolume == 0)

        bundle.controller.updateMusicVolume(0.5)
        #expect(spy.lastOutputSettings?.musicVolume == 0.5)
    }

    @Test("11b settings changes invalidate controller presentation")
    func settingsChangesPublishPresentationUpdate() throws {
        let bundle = try TestPlayControllerFactory.make(markIntroDismissed: true)
        var publicationCount = 0
        let observation = bundle.controller.objectWillChange.sink {
            publicationCount += 1
        }

        bundle.controller.updateMusicVolume(0.35)

        #expect(publicationCount > 0)
        #expect(bundle.controller.settingsSnapshot.musicVolume == 0.35)
        #expect(bundle.controller.settingsPresentation.musicVolume == 0.35)
        withExtendedLifetime(observation) {}
    }

    @Test("12 mute zeros effective music and effects gain")
    func muteAffectsMusicAndEffects() throws {
        let spy = SpyAudioPlaybackBackend()
        let bundle = try TestPlayControllerFactory.make(
            audioDirector: AudioDirector(backend: spy),
            markIntroDismissed: true
        )
        bundle.controller.updateMusicVolume(0.8)
        bundle.controller.updateEffectsVolume(1.0)
        bundle.controller.updateMuted(true)
        let settings = try #require(spy.lastOutputSettings)
        #expect(settings.isMuted)
        #expect(settings.effectiveMusicGain == 0)
        #expect(settings.effectiveEffectsGain == 0)
    }

    @Test("13 effective reduce motion is system OR app toggle")
    func reduceMotionIsOr() throws {
        let bundle = try TestPlayControllerFactory.make(markIntroDismissed: true)
        #expect(bundle.controller.reduceMotionProvider.isReduceMotionEffective == false)
        #expect(bundle.controller.scene.prefersReducedMotion == false)

        bundle.controller.updateReduceMotionEnabled(true)
        #expect(bundle.controller.reduceMotionProvider.isReduceMotionEffective == true)
        #expect(bundle.controller.scene.prefersReducedMotion == true)

        bundle.controller.updateReduceMotionEnabled(false)
        bundle.reduceMotion.systemReduceMotionEnabled = true
        #expect(bundle.controller.reduceMotionProvider.isReduceMotionEffective == true)
        #expect(bundle.controller.scene.prefersReducedMotion == true)
    }

    @Test("14 reduce motion does not change authoritative game state")
    func reduceMotionDoesNotAlterCoreState() throws {
        let bundle = try TestPlayControllerFactory.make(markIntroDismissed: true)
        let before = try #require(bundle.controller.session).revision
        let moveCount = bundle.controller.moveCount

        bundle.controller.updateReduceMotionEnabled(true)
        #expect(bundle.controller.scene.prefersReducedMotion == true)
        #expect(bundle.controller.session?.revision == before)
        #expect(bundle.controller.moveCount == moveCount)
        #expect(bundle.controller.presentationPhase == .playing)
    }

    @Test("15 outcome undo is only available when canUndo")
    func outcomeUndoOnlyWhenCanUndo() throws {
        let bundle = try TestPlayControllerFactory.make(markIntroDismissed: true)
        playMoves(bundle.controller, SokobanTutorialSolutions.level001)
        awaitOutcome(bundle.controller)
        #expect(bundle.controller.canUndo)
        #expect(bundle.controller.outcomePresentation.undoEnabled)
        #expect(
            bundle.controller.outcomePresentation.metrics.map(\.id)
                == ["moves", "pushes", "goals"]
        )

        // After undoing back and with empty undo stack mid-play, undo is unavailable.
        bundle.controller.undoFromOutcomeOverlay()
        #expect(bundle.controller.presentationPhase == .playing)
        #expect(!bundle.controller.canUndo)
    }

    @Test("16 focus / return / space / double-key guards stay green via outcome path")
    func outcomeConfirmGuardsRemain() throws {
        let bundle = try TestPlayControllerFactory.make(markIntroDismissed: true)
        playMoves(bundle.controller, SokobanTutorialSolutions.level001)
        awaitOutcome(bundle.controller)

        bundle.controller.setFocusedOutcomeAction(.again)
        _ = bundle.controller.router.route(TestKeyEvent.keyUp(KeyCode.rightArrow))
        _ = bundle.controller.router.route(TestKeyEvent.keyUp(KeyCode.return))
        bundle.controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.return))
        #expect(bundle.controller.currentLevelID == "sokoban.tutorial.001")
        #expect(bundle.controller.presentationPhase == .playing)
        #expect(bundle.controller.moveCount == 0)
    }

    @Test("17 locked levels cannot be started")
    func lockedLevelsCannotStart() throws {
        let bundle = try TestPlayControllerFactory.make(markIntroDismissed: true)
        #expect(
            bundle.progress.availability(for: "sokoban.tutorial.003", in: bundle.catalog)
                == .locked
        )
        let before = bundle.controller.currentLevelID
        bundle.controller.startSelectedLevel(id: "sokoban.tutorial.003")
        #expect(bundle.controller.currentLevelID == before)
        #expect(bundle.controller.presentationPhase == .playing)
    }

    @Test("restart and play-again do not re-show a seen intro")
    func restartDoesNotReshowSeenIntro() throws {
        let bundle = try TestPlayControllerFactory.make(markIntroDismissed: true)
        playMoves(bundle.controller, SokobanTutorialSolutions.level001)
        awaitOutcome(bundle.controller)
        bundle.controller.restartFromOutcomeOverlay()
        #expect(bundle.controller.presentationPhase == .playing)
        #expect(bundle.scheduler.pendingCount == 0)
    }

    @Test("help from pause blocks gameplay input")
    func helpBlocksGameplay() throws {
        let bundle = try TestPlayControllerFactory.make(markIntroDismissed: true)
        bundle.controller.togglePause()
        bundle.controller.openHelpFromPause()
        let revision = try #require(bundle.controller.session).revision
        bundle.controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.rightArrow))
        #expect(bundle.controller.session?.revision == revision)
        #expect(bundle.controller.router.mode == .modalBlocked)
    }

    @Test("help/settings from pause reject menu undo and restart without resuming")
    func helpSettingsRejectMenuSessionCommands() throws {
        let bundle = try TestPlayControllerFactory.make(markIntroDismissed: true)
        // Level 1 completes on a single push; use level 2 for a non-terminal undo step.
        // Bypass unlock gate (startSelectedLevel would reject a locked level).
        bundle.controller.startLevel(id: "sokoban.tutorial.002", showIntro: false)
        playMoves(bundle.controller, [.right])
        #expect(bundle.controller.presentationPhase == .playing)
        #expect(bundle.controller.canUndo)

        bundle.controller.togglePause()
        #expect(bundle.controller.canUndo)
        #expect(bundle.controller.canRestart)

        bundle.controller.openHelpFromPause()
        #expect(!bundle.controller.canUndo)
        #expect(!bundle.controller.canRestart)
        let revision = try #require(bundle.controller.session).revision
        bundle.controller.undo()
        bundle.controller.restart()
        #expect(bundle.controller.presentationPhase == .help)
        #expect(bundle.controller.session?.phase == .paused)
        #expect(bundle.controller.session?.revision == revision)

        bundle.controller.dismissHelpOrSettings()
        bundle.controller.openSettingsFromPause()
        #expect(!bundle.controller.canUndo)
        bundle.controller.undo()
        #expect(bundle.controller.presentationPhase == .settings)
        #expect(bundle.controller.session?.phase == .paused)
        #expect(bundle.controller.session?.revision == revision)
    }

    @Test("workspace reduce-motion notifications refresh the effective flag")
    func workspaceNotificationCenterDeliversReduceMotionChanges() async throws {
        let center = NotificationCenter()
        let settings = AppSettingsStore.ephemeral()
        let source = WorkspaceReduceMotionSource(notificationCenter: center)
        let provider = ReduceMotionProvider(settings: settings, systemSource: source)
        var observed = 0
        provider.onEffectiveChange = { _ in observed += 1 }

        center.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        // Delivery is scheduled on the main run loop via receive(on:).
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(observed >= 1)
    }
}
