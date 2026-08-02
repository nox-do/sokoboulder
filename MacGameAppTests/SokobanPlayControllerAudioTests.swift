import Foundation
import Testing
@testable import GameCore
@testable import MacGameApp

@Suite("SokobanPlayController audio wiring")
@MainActor
struct SokobanPlayControllerAudioTests {
    private func makeController() -> (SokobanPlayController, SpyAudioPlaybackBackend) {
        let spy = SpyAudioPlaybackBackend()
        let director = AudioDirector(backend: spy)
        let persistence = try! SokobanRunPersistence.ephemeral()
        let catalog = try! BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        let progress = try! ProgressPersistence.ephemeral(firstLevelID: catalog.first.id)
        let controller = SokobanPlayController(
            audioDirector: director,
            runPersistence: persistence,
            progressPersistence: progress,
            catalog: catalog,
            settingsStore: AppSettingsStore.ephemeral(),
            assistiveReadingProbe: ManualAssistiveReadingProbe(),
            delayedActionScheduler: ManualDelayedActionScheduler()
        )
        controller.dismissLevelIntro()
        return (controller, spy)
    }

    @Test("start and move share render/audio target revision; cue plays once")
    func emissionReachesAudio() throws {
        let (controller, spy) = makeController()
        #expect(controller.audioDirector.lastAppliedRevision == 1)
        #expect(spy.musicStates.contains(.sokobanLoop))
        spy.resetCalls()

        // Demo: move right completes #@$.# → push onto goal.
        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.rightArrow))
        let revision = try #require(controller.session).revision
        #expect(controller.audioDirector.lastAppliedRevision == revision)
        #expect(controller.scene.appliedRevision == revision)
        #expect(spy.playedEffects == [.cratePushed, .goalEntered, .levelCompleted])
        #expect(spy.playedEffects.filter { $0 == .cratePushed }.count == 1)
    }

    @Test("undo after completion does not replay completion cues and stops effects")
    func undoDoesNotReplayCues() throws {
        let (controller, spy) = makeController()
        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.rightArrow))
        spy.resetCalls()

        controller.undo()
        #expect(spy.playedEffects.isEmpty)
        #expect(spy.calls.contains(.stopAllEffects))
        #expect(spy.musicStates.contains(.sokobanLoop))
    }

    @Test("pause interrupt leaves no audible music; resume restores loop")
    func pauseInterruptLifecycle() {
        let (controller, spy) = makeController()
        spy.resetCalls()

        controller.togglePause()
        #expect(spy.calls.contains(.stopAllEffects))
        #expect(spy.musicStates.last == .stopped)

        spy.resetCalls()
        controller.resumeFromPauseOverlay()
        #expect(spy.playedEffects.isEmpty)
        #expect(spy.musicStates == [.sokobanLoop])
    }

    @Test("focus loss interrupts audio like pause")
    func focusLossInterruptsAudio() {
        let (controller, spy) = makeController()
        spy.resetCalls()
        controller.handleAppDeactivation()
        #expect(spy.calls.contains(.stopAllEffects))
        #expect(spy.musicStates.last == .stopped)
    }

    @Test("focus loss during outcome interrupts; activation resumes without cues")
    func focusLossDuringOutcomeInterruptsAudio() throws {
        let (controller, spy) = makeController()
        controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.rightArrow))
        controller.scene.settleAnimationsForTesting()
        if controller.presentationPhase == .outcomeAnimating {
            controller.skipOutcomePresentation()
        }
        #expect(controller.presentationPhase == .outcomeAwaitingChoice)
        spy.resetCalls()

        controller.handleAppDeactivation()
        #expect(controller.presentationPhase == .outcomeAwaitingChoice)
        #expect(spy.calls.contains(.stopAllEffects))
        #expect(spy.musicStates.last == .stopped)

        spy.resetCalls()
        controller.handleAppActivation()
        #expect(spy.playedEffects.isEmpty)
        // Completed context keeps music stopped; resume only clears interrupt.
        #expect(!spy.calls.contains(.playEffect(.levelCompleted)))
    }
}
