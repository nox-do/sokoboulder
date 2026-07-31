import AppKit
import Combine
import GameCore
import SwiftUI

/// Minimal Phase-2 spike controller: session + input router + board scene.
///
/// Full HUD / outcome polish follows in a later step; this makes the board
/// keyboard-playable at app launch.
@MainActor
final class SokobanSpikeController: ObservableObject {
    let scene: SokobanBoardScene
    let router = GameplayInputRouter()

    private(set) var session: GameSession?

    @Published private(set) var phaseLabel = "Loading…"
    @Published private(set) var hudLine = ""
    @Published private(set) var banner: String?
    @Published private(set) var isFaulted = false

    private let demoASCII = """
        #####
        #@$.#
        #####
        """

    init() {
        scene = SokobanBoardScene(size: CGSize(width: 640, height: 480))
        startLevel()
    }

    func startLevel() {
        do {
            let level = try SokobanLevelValidator.level(fromASCII: demoASCII)
            let newSession = try GameSession(level: level, levelID: "spike.demo")
            let emission = newSession.start()
            session = newSession
            isFaulted = false
            router.enterGameplay()
            scene.apply(emission.render)
            refreshPresentation(from: emission)
        } catch {
            session = nil
            isFaulted = true
            banner = "Failed to load demo level: \(error)"
            phaseLabel = "Faulted"
        }
    }

    func handleKeyEvent(_ event: NSEvent) {
        guard !isFaulted else { return }
        guard let routed = router.route(event) else { return }

        switch routed {
        case .gameplay(let intent):
            handleGameplay(intent)
        case .outcomeAction:
            // Spike: confirm restarts the level (full outcome UI comes later).
            applySessionCommand(.restart)
        }
    }

    func handleAppDeactivation() {
        // Always drop held/locked keys — key-up often never arrives while inactive.
        router.clearPendingInputs()

        guard let session else { return }

        switch session.phase {
        case .playing:
            session.pause()
            router.enterPaused()
            banner = "Paused — click the board, then press Escape to resume"
            phaseLabel = "Paused"
        case .outcomePresenting, .paused, .created, .faulted:
            break
        }
    }

    // MARK: - Private

    private func handleGameplay(_ intent: GameplayIntent) {
        guard let session else { return }

        switch intent {
        case .move(let direction):
            guard session.phase == .playing else { return }
            applyResults(session.submitMove(direction))

        case .undo:
            resumeIfPaused(session)
            applySessionCommand(.undo)

        case .redo:
            resumeIfPaused(session)
            applySessionCommand(.redo)

        case .restart:
            resumeIfPaused(session)
            applySessionCommand(.restart)

        case .pause:
            togglePause()
        }
    }

    private func resumeIfPaused(_ session: GameSession) {
        guard session.phase == .paused else { return }
        session.resume()
        router.enterGameplay()
        banner = nil
    }

    private func togglePause() {
        guard let session else { return }
        switch session.phase {
        case .playing:
            session.pause()
            router.enterPaused()
            banner = "Paused — Escape to resume · R restart · Z undo"
            phaseLabel = "Paused"
        case .paused:
            session.resume()
            router.enterGameplay()
            banner = nil
            refreshHUD(from: session)
        default:
            break
        }
    }

    private func applySessionCommand(_ command: SessionCommand) {
        guard let session else { return }
        let result = session.apply(command)
        applyResults([result])
        if session.phase == .playing {
            router.enterGameplay()
        }
    }

    private func applyResults(_ results: [SessionApplyResult]) {
        guard let session else { return }

        for result in results {
            switch result {
            case .ignored:
                continue

            case .emitted(let emission):
                scene.apply(emission.render)
                refreshPresentation(from: emission)

            case .faulted(let message):
                isFaulted = true
                router.enterModalBlocked()
                scene.discardPendingPresentation()
                banner = "Engine fault: \(message)"
                phaseLabel = "Faulted"
                self.session = nil
                return
            }
        }

        refreshHUD(from: session)
    }

    private func refreshPresentation(from emission: SessionEmission) {
        if emission.appTransition == .enterOutcomePresenting {
            router.enterOutcomePresenting()
            banner = "Level complete — Return/Space continue · Z undo · R restart"
            phaseLabel = "Completed"
        } else if emission.appTransition == .returnToPlaying {
            router.enterGameplay()
            banner = nil
            phaseLabel = "Playing"
        }
    }

    private func refreshHUD(from session: GameSession) {
        switch session.phase {
        case .playing:
            phaseLabel = "Playing"
            if banner?.hasPrefix("Paused") == true { banner = nil }
        case .paused:
            phaseLabel = "Paused"
        case .outcomePresenting:
            phaseLabel = "Completed"
        case .faulted:
            phaseLabel = "Faulted"
        case .created:
            phaseLabel = "Loading…"
        }

        // Snapshot counters from the scene's last accepted render state.
        if let snapshot = scene.currentSnapshot {
            hudLine = "Moves \(snapshot.moveCount) · Pushes \(snapshot.pushCount)"
        } else {
            hudLine = ""
        }
    }
}
