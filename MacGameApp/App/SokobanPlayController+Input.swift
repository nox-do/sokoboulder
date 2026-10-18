import AppKit
import GameCore

// Keyboard dispatch, held movement, and cave ticks.
extension SokobanPlayController {
    /// Routes a platform key event. Returns `true` when the event was consumed.
    @discardableResult
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard presentationPhase != .faulted, presentationPhase != .runRecovery else {
            return false
        }
        if handleMoveHoldKeyUp(event) {
            return true
        }
        switch router.routeDecision(event) {
        case .unhandled:
            return handleOverlayMenuKeyEvent(event)
        case .consumed:
            return true
        case .routed(let routed):
            switch routed {
            case .gameplay(let intent):
                handleGameplay(intent, keyCode: event.keyCode)
            case .outcomeAction:
                handleOutcomeAction()
            case .dismissIntro:
                dismissLevelIntro()
            }
            return true
        }
    }

    func bindMoveHoldRepeater() {
        moveHoldRepeater.onFire = { [weak self] direction in
            self?.performHeldMove(direction)
        }
    }

    func bindSimulationClock() {
        scene.onSimulationFrame = { [weak self] in
            self?.advanceCaveSimulation()
        }
    }

    private func advanceCaveSimulation() {
        guard case .cave(let caveSession) = activePlay else { return }
        guard presentationPhase == .playing else { return }
        guard caveSession.phase == .playing || caveSession.phase == .ready else { return }
        do {
            guard let emission = try caveSession.advance(to: clock.now(), heldDirection: router.heldDirection) else {
                return
            }
            applyResult(.emitted(emission))
        } catch {
            applyResult(.faulted(message: String(describing: error)))
        }
    }

    private func handleMoveHoldKeyUp(_ event: NSEvent) -> Bool {
        guard event.type == .keyUp else { return false }
        guard InputMapper.moveDirection(keyCode: event.keyCode) != nil else { return false }
        _ = router.routeDecision(event)
        moveHoldRepeater.noteKeyUp(keyCode: event.keyCode)
        return true
    }

    func clearMoveHold() {
        moveHoldRepeater.clear()
    }

    private func performHeldMove(_ direction: Direction) {
        guard presentationPhase == .playing, let session, session.phase == .playing else {
            clearMoveHold()
            return
        }
        applyResult(session.submitMove(direction))
        gameplayNotice =
            session.preventedStaticDeadlockOnLastMove
            ? AppStrings.text(.uiDeadlockPrevented)
            : nil
    }

    private func handleGameplay(_ intent: GameplayIntent, keyCode: UInt16) {
        if isCaveMode {
            handleCaveGameplay(intent)
            return
        }
        switch intent {
        case .move(let direction):
            guard presentationPhase == .playing, let session, session.phase == .playing else {
                return
            }
            moveHoldRepeater.noteKeyDown(keyCode: keyCode, direction: direction)

        case .wait:
            break

        case .toggleGoalMarker:
            guard presentationPhase == .playing else { return }
            scene.toggleGoalBookmarkAtPlayer()

        case .undo:
            clearMoveHold()
            undo()

        case .redo:
            clearMoveHold()
            redo()

        case .restart:
            clearMoveHold()
            restart()

        case .pause:
            clearMoveHold()
            togglePause()
        }
    }

    private func handleCaveGameplay(_ intent: GameplayIntent) {
        guard let caveSession else { return }
        switch intent {
        case .move(let direction):
            guard presentationPhase == .playing, caveSession.canAcceptInput else { return }
            caveSession.noteDirectionDown(direction)
            // Kick Tick 1 immediately when leaving Ready.
            advanceCaveSimulation()

        case .wait:
            guard presentationPhase == .playing, caveSession.canAcceptInput else { return }
            caveSession.noteWait()
            advanceCaveSimulation()

        case .restart:
            restartCave()

        case .pause:
            togglePause()

        case .undo, .redo, .toggleGoalMarker:
            break
        }
    }

    private func handleOutcomeAction() {
        guard presentationPhase == .outcomeAwaitingChoice else { return }
        performFocusedOutcomeAction()
    }
}
