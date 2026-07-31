import Testing
@testable import GameCore
@testable import MacGameApp

@Suite("SokobanSpikeController focus loss")
@MainActor
struct SokobanSpikeControllerTests {
    @Test("deactivation during outcome clears locks without pausing the session")
    func deactivationDuringOutcome() throws {
        let controller = SokobanSpikeController()
        let session = try #require(controller.session)
        #expect(session.phase == .playing)

        // Complete the demo level with the terminal move still notionally held.
        #expect(
            controller.router.route(TestKeyEvent.keyDown(KeyCode.rightArrow))
                == .gameplay(.move(.right))
        )
        let results = session.submitMove(.right)
        guard case .emitted(let emission) = results[0] else {
            Issue.record("expected completion")
            return
        }
        controller.scene.apply(emission.render)
        if emission.appTransition == .enterOutcomePresenting {
            controller.router.enterOutcomePresenting()
        }
        #expect(session.phase == .outcomePresenting)
        #expect(controller.router.lockedKeyCodes.contains(KeyCode.rightArrow))
        #expect(controller.router.outcomeGateOpen == false)

        controller.handleAppDeactivation()

        #expect(session.phase == .outcomePresenting)
        #expect(controller.router.lockedKeyCodes.isEmpty)
        #expect(controller.router.outcomeGateOpen)
        #expect(
            controller.router.route(TestKeyEvent.keyDown(KeyCode.z, characters: "z"))
                == .gameplay(.undo)
        )
        #expect(
            controller.router.route(TestKeyEvent.keyDown(KeyCode.return))
                == .outcomeAction
        )
    }

    @Test("deactivation while playing pauses and clears input")
    func deactivationWhilePlaying() throws {
        let controller = SokobanSpikeController()
        let session = try #require(controller.session)

        _ = controller.router.route(TestKeyEvent.keyDown(KeyCode.leftArrow))
        #expect(controller.router.pressedKeyCodes.contains(KeyCode.leftArrow))

        controller.handleAppDeactivation()

        #expect(session.phase == .paused)
        #expect(controller.router.mode == .paused)
        #expect(controller.router.pressedKeyCodes.isEmpty)
        #expect(controller.router.lockedKeyCodes.isEmpty)
    }
}
