import AVFoundation
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
            settingsStore: AppSettingsStore.ephemeral()
        )
        controller.dismissLevelIntro()
        return (controller, spy)
    }

    private func completeFirstLevel(_ controller: SokobanPlayController) {
        for (index, _) in SokobanTutorialSolutions.level001.enumerated() {
            controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.rightArrow))
            if index < SokobanTutorialSolutions.level001.count - 1 {
                controller.handleKeyEvent(TestKeyEvent.keyUp(KeyCode.rightArrow))
            }
        }
    }

    @Test("start and move share render/audio target revision; cue plays once")
    func emissionReachesAudio() throws {
        let (controller, spy) = makeController()
        #expect(controller.audioDirector.lastAppliedRevision == 1)
        #expect(spy.musicStates.contains(.sokobanLoop))
        spy.resetCalls()

        completeFirstLevel(controller)
        let revision = try #require(controller.session).revision
        #expect(controller.audioDirector.lastAppliedRevision == revision)
        #expect(controller.scene.appliedRevision == revision)
        #expect(
            spy.playedEffects
                == [.step, .cratePushed, .cratePushed, .goalEntered, .levelCompleted]
        )
        #expect(spy.playedEffects.filter { $0 == .cratePushed }.count == 2)
    }

    @Test("undo after completion does not replay completion cues and stops effects")
    func undoDoesNotReplayCues() throws {
        let (controller, spy) = makeController()
        completeFirstLevel(controller)
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
        completeFirstLevel(controller)
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

    @Test("bundled Sokoban music is present and natively decodable")
    func bundledMusicIsDecodable() throws {
        let bundle = Bundle(for: SokobanPlayController.self)
        let url = try #require(ProceduralAudioPlaybackBackend.musicAssetURL(in: bundle))
        let file = try AVAudioFile(forReading: url)

        #expect(url.lastPathComponent == "sokoban-puzzling.mp3")
        #expect(file.length > AVAudioFramePosition(file.processingFormat.sampleRate * 90))
    }
}
