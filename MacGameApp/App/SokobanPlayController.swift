import AppKit
import Combine
import GameCore
import SwiftUI

/// App-layer controller for one Sokoban window: session, input, scene, overlays.
@MainActor
final class SokobanPlayController: ObservableObject {
    static let outcomePresentationTimeout: TimeInterval = 0.45

    #if DEBUG
    /// Test override for the outcome settle timeout.
    var outcomePresentationTimeoutForTesting: TimeInterval?
    #endif

    let scene: SokobanBoardScene
    let router = GameplayInputRouter()

    private(set) var session: GameSession?

    @Published private(set) var presentationPhase: GamePresentationPhase = .playing
    @Published private(set) var levelTitle = "Demo"
    @Published private(set) var moveCount = 0
    @Published private(set) var pushCount = 0
    @Published private(set) var completedGoalCount = 0
    @Published private(set) var totalGoalCount = 0
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var canPause = false
    @Published private(set) var canResume = false
    @Published private(set) var canRestart = false
    @Published private(set) var faultMessage: String?
    @Published private(set) var outcomeHint = "Press Return when ready"

    private var outcomeTimeoutItem: DispatchWorkItem?
    private var outcomeTargetRevision: UInt64?
    private var outcomeGeneration: UInt64 = 0

    private let demoASCII = """
        #####
        #@$.#
        #####
        """
    private let demoLevelID = "spike.demo"
    private let demoLevelTitle = "Demo 1"

    init() {
        scene = SokobanBoardScene(size: CGSize(width: 640, height: 480))
        startLevel()
    }

    // MARK: - Lifecycle

    func startLevel() {
        cancelOutcomeWait()
        // New GameSession restarts revisions at 0→1; clear stale settledRevision.
        scene.prepareForNewSession()
        do {
            let level = try SokobanLevelValidator.level(fromASCII: demoASCII)
            let newSession = try GameSession(level: level, levelID: demoLevelID)
            let emission = newSession.start()
            session = newSession
            faultMessage = nil
            levelTitle = demoLevelTitle
            presentationPhase = .playing
            router.enterGameplay()
            scene.apply(emission.render)
            applyEmissionSideEffects(emission)
            refreshPublishedState()
        } catch {
            session = nil
            presentationPhase = .faulted
            faultMessage = "Failed to load level: \(error)"
            router.enterModalBlocked()
            refreshPublishedState()
        }
    }

    // MARK: - Input

    /// Routes a platform key event. Returns `true` when the event was consumed.
    @discardableResult
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard presentationPhase != .faulted else { return false }
        switch router.routeDecision(event) {
        case .unhandled:
            return false
        case .consumed:
            return true
        case .routed(let routed):
            switch routed {
            case .gameplay(let intent):
                handleGameplay(intent)
            case .outcomeAction:
                handleOutcomeAction()
            }
            return true
        }
    }

    func handleAppDeactivation() {
        router.clearPendingInputs()
        guard let session else { return }

        switch session.phase {
        case .playing:
            pauseFromShell()
        case .outcomePresenting, .paused, .created, .faulted:
            break
        }
    }

    // MARK: - Shared command API (keyboard, overlay, menu)

    func undo() {
        guard canUndo else { return }
        resumeIfPaused()
        applySessionCommand(.undo)
    }

    func redo() {
        guard canRedo else { return }
        resumeIfPaused()
        applySessionCommand(.redo)
    }

    func restart() {
        guard canRestart else { return }
        resumeIfPaused()
        if presentationPhase == .outcomeAnimating || presentationPhase == .outcomeAwaitingChoice {
            cancelOutcomeWait()
        }
        applySessionCommand(.restart)
    }

    func togglePause() {
        guard let session else { return }
        switch presentationPhase {
        case .playing where session.phase == .playing:
            pauseFromShell()
        case .paused:
            resumeFromShell()
        default:
            break
        }
    }

    func resumeFromPauseOverlay() {
        resumeFromShell()
    }

    func restartFromPauseOverlay() {
        restart()
    }

    func restartFromOutcomeOverlay() {
        restart()
    }

    func undoFromOutcomeOverlay() {
        undo()
    }

    /// Skips remaining terminal presentation and opens the result overlay.
    func skipOutcomePresentation() {
        guard presentationPhase == .outcomeAnimating else { return }
        scene.discardPendingPresentation()
        enterOutcomeAwaitingChoice()
    }

    // MARK: - Private gameplay

    private func handleGameplay(_ intent: GameplayIntent) {
        switch intent {
        case .move(let direction):
            guard presentationPhase == .playing, let session, session.phase == .playing else { return }
            applyResults(session.submitMove(direction))

        case .undo:
            undo()

        case .redo:
            redo()

        case .restart:
            restart()

        case .pause:
            togglePause()
        }
    }

    private func handleOutcomeAction() {
        switch presentationPhase {
        case .outcomeAnimating:
            // Same physical confirm key must not also activate the result action.
            skipOutcomePresentation()
        case .outcomeAwaitingChoice:
            restartFromOutcomeOverlay()
        default:
            break
        }
    }

    private func pauseFromShell() {
        guard let session, session.phase == .playing else { return }
        session.pause()
        router.enterPaused()
        presentationPhase = .paused
        refreshPublishedState()
    }

    private func resumeFromShell() {
        guard let session, session.phase == .paused else { return }
        session.resume()
        router.enterGameplay()
        presentationPhase = .playing
        refreshPublishedState()
    }

    private func resumeIfPaused() {
        guard let session, session.phase == .paused else { return }
        session.resume()
        // Caller continues with a command; router mode is set by applyResults.
    }

    private func applySessionCommand(_ command: SessionCommand) {
        guard let session else { return }
        let result = session.apply(command)
        applyResults([result])
    }

    private func applyResults(_ results: [SessionApplyResult]) {
        for result in results {
            switch result {
            case .ignored:
                continue

            case .emitted(let emission):
                scene.apply(emission.render)
                applyEmissionSideEffects(emission)

            case .faulted(let message):
                cancelOutcomeWait()
                presentationPhase = .faulted
                faultMessage = message
                router.enterModalBlocked()
                scene.discardPendingPresentation()
                session = nil
                refreshPublishedState()
                return
            }
        }
        refreshPublishedState()
    }

    private func applyEmissionSideEffects(_ emission: SessionEmission) {
        switch emission.appTransition {
        case .enterOutcomePresenting:
            beginOutcomeAnimating(targetRevision: emission.render.targetRevision)
        case .returnToPlaying:
            cancelOutcomeWait()
            presentationPhase = .playing
            router.enterGameplay()
        case nil:
            guard let session else { return }
            if session.phase == .playing {
                // Covers restart/undo from pause as well as normal moves.
                presentationPhase = .playing
                if router.mode != .gameplay {
                    router.enterGameplay()
                }
            }
        }
    }

    private func beginOutcomeAnimating(targetRevision: UInt64) {
        cancelOutcomeWait()
        presentationPhase = .outcomeAnimating
        router.enterOutcomePresenting()
        outcomeTargetRevision = targetRevision
        outcomeGeneration &+= 1
        let generation = outcomeGeneration

        scene.whenSettled(revision: targetRevision) { [weak self] in
            guard let self else { return }
            guard generation == self.outcomeGeneration else { return }
            guard self.presentationPhase == .outcomeAnimating else { return }
            self.enterOutcomeAwaitingChoice()
        }

        let timeout = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard generation == self.outcomeGeneration else { return }
            guard self.presentationPhase == .outcomeAnimating else { return }
            self.scene.discardPendingPresentation()
            self.enterOutcomeAwaitingChoice()
        }
        outcomeTimeoutItem = timeout
        let delay: TimeInterval
        #if DEBUG
        delay = outcomePresentationTimeoutForTesting ?? Self.outcomePresentationTimeout
        #else
        delay = Self.outcomePresentationTimeout
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: timeout)
    }

    private func enterOutcomeAwaitingChoice() {
        cancelOutcomeWait(clearGeneration: false)
        presentationPhase = .outcomeAwaitingChoice
        if router.mode != .outcomePresenting {
            router.enterOutcomePresenting()
        }
        router.releaseOutcomeLocksPreservingPressedKeys()
        outcomeHint = "Return: play again · Z: undo"
        refreshPublishedState()
    }

    private func cancelOutcomeWait(clearGeneration: Bool = true) {
        outcomeTimeoutItem?.cancel()
        outcomeTimeoutItem = nil
        outcomeTargetRevision = nil
        if clearGeneration {
            outcomeGeneration &+= 1
        }
    }

    private func refreshPublishedState() {
        guard let session else {
            canUndo = false
            canRedo = false
            canPause = false
            canResume = false
            canRestart = false
            return
        }

        canUndo = session.undoCount > 0
            && (session.canAcceptSessionCommand || session.phase == .paused)
        canRedo = session.redoCount > 0
            && (session.canAcceptSessionCommand || session.phase == .paused)
        canRestart = session.phase == .playing
            || session.phase == .paused
            || session.phase == .outcomePresenting
        canPause = presentationPhase == .playing && session.phase == .playing
        canResume = presentationPhase == .paused

        if let snapshot = scene.currentSnapshot {
            moveCount = snapshot.moveCount
            pushCount = snapshot.pushCount
            completedGoalCount = snapshot.completedGoalCount
            totalGoalCount = snapshot.totalGoalCount
        }
    }
}
