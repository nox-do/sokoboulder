import AppKit
import Testing
@testable import GameCore
@testable import MacGameApp

@Suite("GameplayInputRouter outcome / modal gates")
@MainActor
struct GameplayInputRouterTests {
    private func startedSession() throws -> GameSession {
        let level = try SokobanLevelValidator.level(
            fromASCII: """
            #####
            #@$.#
            #####
            """
        )
        let session = try GameSession(level: level, levelID: "gate")
        _ = session.start()
        return session
    }

    @Test("terminal key-down moves once and does not confirm outcome until fresh key-down")
    func terminalKeyOutcomeGate() throws {
        let session = try startedSession()
        let router = GameplayInputRouter()
        router.enterGameplay()

        let down = TestKeyEvent.keyDown(KeyCode.rightArrow)
        let routed = router.route(down)
        #expect(routed == .gameplay(.move(.right)))

        let results = session.submitMove(.right)
        #expect(results.count == 1)
        guard case .emitted(let emission) = results[0] else {
            Issue.record("expected completion emission")
            return
        }
        #expect(emission.appTransition == .enterOutcomePresenting)
        #expect(session.phase == .outcomePresenting)

        router.enterOutcomePresenting()
        #expect(router.lockedKeyCodes.contains(KeyCode.rightArrow))
        #expect(router.outcomeGateOpen == false)

        // Same physical key still down must not confirm the dialog.
        #expect(router.route(down) == nil)

        // Return pressed while the terminal key is held is tracked, not confirmed.
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.return)) == nil)
        #expect(router.pressedKeyCodes.contains(KeyCode.return))

        // Terminal key-up unlocks the gate; held Return still must not confirm.
        #expect(router.route(TestKeyEvent.keyUp(KeyCode.rightArrow)) == nil)
        #expect(router.outcomeGateOpen)
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.return)) == nil)

        // Only after Return key-up is a later independent key-down allowed.
        #expect(router.route(TestKeyEvent.keyUp(KeyCode.return)) == nil)
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.return)) == .outcomeAction)
    }

    @Test("outcome confirm ignores key-repeat")
    func outcomeRejectsRepeat() throws {
        let router = GameplayInputRouter()
        router.enterGameplay()
        router.enterOutcomePresenting()
        #expect(router.outcomeGateOpen)

        #expect(
            router.route(TestKeyEvent.keyDown(KeyCode.return, isARepeat: true)) == nil
        )
        #expect(
            router.routeDecision(TestKeyEvent.keyDown(KeyCode.return, isARepeat: true))
                == .consumed
        )
        #expect(
            router.route(TestKeyEvent.keyDown(KeyCode.return)) == .outcomeAction
        )
    }

    @Test("outcome distinguishes suppressed confirm from unrelated key")
    func outcomeRoutingDecision() {
        let router = GameplayInputRouter()
        router.enterGameplay()
        router.enterOutcomePresenting()

        #expect(
            router.routeDecision(TestKeyEvent.keyDown(KeyCode.return))
                == .routed(.outcomeAction)
        )
        #expect(
            router.routeDecision(TestKeyEvent.keyDown(KeyCode.return)) == .consumed
        )
        #expect(
            router.routeDecision(TestKeyEvent.keyDown(9, characters: "v")) == .unhandled
        )
    }

    @Test("Return held during gameplay cannot confirm after entering outcome")
    func heldReturnDuringGameplayBlocked() {
        let router = GameplayInputRouter()
        router.enterGameplay()
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.return)) == nil)
        #expect(router.pressedKeyCodes.contains(KeyCode.return))

        router.enterOutcomePresenting()
        #expect(router.lockedKeyCodes.contains(KeyCode.return))
        #expect(router.outcomeGateOpen == false)
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.return)) == nil)

        #expect(router.route(TestKeyEvent.keyUp(KeyCode.return)) == nil)
        #expect(router.outcomeGateOpen)
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.return)) == .outcomeAction)
    }

    @Test("gameplay input disabled during modal UI")
    func modalBlocksGameplay() {
        let router = GameplayInputRouter()
        router.enterGameplay()
        router.enterModalBlocked()
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.rightArrow)) == nil)
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.z, characters: "z")) == nil)
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.escape)) == nil)
    }

    @Test("undo remains routable after outcome gate opens")
    func undoAfterOutcomeGate() throws {
        let session = try startedSession()
        let router = GameplayInputRouter()
        router.enterGameplay()

        #expect(router.route(TestKeyEvent.keyDown(KeyCode.rightArrow)) == .gameplay(.move(.right)))
        _ = session.submitMove(.right)
        router.enterOutcomePresenting()
        _ = router.route(TestKeyEvent.keyUp(KeyCode.rightArrow))

        #expect(router.route(TestKeyEvent.keyDown(KeyCode.z, characters: "z")) == .gameplay(.undo))
        guard case .emitted = session.apply(.undo) else {
            Issue.record("undo via same session API")
            return
        }
        #expect(session.phase == .playing)
    }

    @Test("clearPendingInputs during outcome opens the gate without a key-up")
    func clearPendingInputsOpensOutcomeGate() {
        let router = GameplayInputRouter()
        router.enterGameplay()
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.rightArrow)) == .gameplay(.move(.right)))
        router.enterOutcomePresenting()
        #expect(router.lockedKeyCodes.contains(KeyCode.rightArrow))
        #expect(router.outcomeGateOpen == false)

        // Focus loss / deactivation path: no key-up will arrive.
        router.clearPendingInputs()
        #expect(router.lockedKeyCodes.isEmpty)
        #expect(router.pressedKeyCodes.isEmpty)
        #expect(router.outcomeGateOpen)
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.return)) == .outcomeAction)
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.z, characters: "z")) == .gameplay(.undo))
    }

    @Test("level intro dismisses on Return Space or Escape")
    func levelIntroDismissKeys() {
        let router = GameplayInputRouter()
        router.enterLevelIntro()
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.rightArrow)) == nil)
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.return)) == .dismissIntro)

        router.enterLevelIntro()
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.space)) == .dismissIntro)

        router.enterLevelIntro()
        #expect(router.route(TestKeyEvent.keyDown(KeyCode.escape)) == .dismissIntro)
    }
}
