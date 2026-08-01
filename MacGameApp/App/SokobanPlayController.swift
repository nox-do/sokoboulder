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
    let audioDirector: AudioDirector
    let runPersistence: SokobanRunPersistence

    private(set) var session: GameSession?

    @Published private(set) var presentationPhase: GamePresentationPhase = .playing
    @Published private(set) var levelTitle = ""
    @Published private(set) var tutorialHintText = ""
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
    /// Blocking recovery copy when a run file cannot be restored.
    @Published private(set) var recoveryMessage: String?
    /// Non-blocking persistence warning; gameplay continues.
    @Published private(set) var persistenceDiagnostic: String?
    @Published private(set) var outcomeHint = ""
    @Published private(set) var outcomeTitle = AppStrings.text(.uiOutcomeLevelComplete)
    @Published private(set) var outcomePrimaryAction: OutcomePrimaryAction = .finishTutorial
    @Published private(set) var outcomePrimaryTitle = AppStrings.text(.uiOutcomeBack)
    /// Keyboard-confirm target while the result overlay is visible.
    @Published private(set) var focusedOutcomeAction: OutcomeFocusedAction = .primary

    private var outcomeTimeoutItem: DispatchWorkItem?
    private var outcomeTargetRevision: UInt64?
    private var outcomeGeneration: UInt64 = 0

    private(set) var currentLevelID: String = SokobanLevelCatalog.first.id

    init(
        audioDirector: AudioDirector = AudioDirector(),
        runPersistence: SokobanRunPersistence
    ) {
        self.audioDirector = audioDirector
        self.scene = SokobanBoardScene(size: CGSize(width: 640, height: 480))
        self.runPersistence = runPersistence
        self.runPersistence.onSaveFailure = { [weak self] message in
            self?.persistenceDiagnostic = "Could not save progress: \(message)"
        }
        if let reason = runPersistence.disabledReason {
            self.persistenceDiagnostic = reason
        }
        bootstrapFromPersistence()
    }

    // MARK: - Lifecycle

    /// Loads a catalog level without consulting the run file (explicit next / recovery).
    ///
    /// Shows the level intro for a fresh catalog entry. In-session restart keeps
    /// the existing session and does not call this path.
    func startLevel(id: String? = nil, showIntro: Bool = true) {
        cancelOutcomeWait()
        audioDirector.reset()
        scene.prepareForNewSession()
        recoveryMessage = nil
        // Keep a disabled-store warning visible; clear transient write errors.
        if let reason = runPersistence.disabledReason {
            persistenceDiagnostic = reason
        } else {
            persistenceDiagnostic = nil
        }

        let levelID = id ?? currentLevelID
        guard let descriptor = SokobanLevelCatalog.descriptor(id: levelID) else {
            session = nil
            presentationPhase = .faulted
            faultMessage = "Unknown level: \(levelID)"
            router.enterModalBlocked()
            audioDirector.reset()
            refreshPublishedState()
            return
        }

        do {
            let level = try descriptor.makeLevel()
            let newSession = try GameSession(
                level: level,
                levelID: descriptor.id,
                contentHash: descriptor.contentHash,
                saveSink: runPersistence
            )
            bootstrapSession(newSession, descriptor: descriptor, showIntro: showIntro)
        } catch {
            session = nil
            presentationPhase = .faulted
            faultMessage = "Failed to load level: \(error)"
            router.enterModalBlocked()
            audioDirector.reset()
            refreshPublishedState()
        }
    }

    /// Clears a bad run and starts catalog level 1.
    func beginFreshRunFromRecovery() {
        runPersistence.removeRunFile()
        recoveryMessage = nil
        currentLevelID = SokobanLevelCatalog.first.id
        startLevel(id: SokobanLevelCatalog.first.id, showIntro: true)
    }

    /// Dismisses the level-intro overlay and begins accepting moves.
    func dismissLevelIntro() {
        guard presentationPhase == .levelIntro else { return }
        presentationPhase = .playing
        router.enterGameplay()
        // Focus may have been lost during intro; ensure playback is audible again.
        audioDirector.resumePlayback()
        refreshPublishedState()
    }

    // MARK: - Input

    /// Routes a platform key event. Returns `true` when the event was consumed.
    @discardableResult
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard presentationPhase != .faulted, presentationPhase != .runRecovery else {
            return false
        }
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
            case .dismissIntro:
                dismissLevelIntro()
            }
            return true
        }
    }

    func handleAppDeactivation() {
        router.clearPendingInputs()
        audioDirector.interrupt()
        Task { await runPersistence.flush() }
        guard let session else { return }

        // Only pause when the player is actively playing — not during intro.
        switch (session.phase, presentationPhase) {
        case (.playing, .playing):
            pauseFromShell(alreadyInterrupted: true)
        default:
            break
        }
    }

    /// Restores audible music after focus return when the shell stayed interactive
    /// without entering pause (outcome or level intro).
    ///
    /// Pause stays interrupted until the player explicitly resumes.
    func handleAppActivation() {
        switch presentationPhase {
        case .outcomeAnimating, .outcomeAwaitingChoice, .levelIntro:
            audioDirector.resumePlayback()
        case .playing, .paused, .faulted, .runRecovery:
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
        if presentationPhase == .levelIntro {
            dismissLevelIntro()
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

    func performOutcomePrimaryAction() {
        guard presentationPhase == .outcomeAwaitingChoice else { return }
        switch outcomePrimaryAction {
        case .nextLevel(let id):
            startLevel(id: id, showIntro: true)
        case .finishTutorial:
            runPersistence.removeRunFile()
            startLevel(id: SokobanLevelCatalog.first.id, showIntro: true)
        }
    }

    /// Confirms the currently focused result-overlay action (Return / Space).
    func performFocusedOutcomeAction() {
        guard presentationPhase == .outcomeAwaitingChoice else { return }
        switch focusedOutcomeAction {
        case .primary:
            performOutcomePrimaryAction()
        case .again:
            restartFromOutcomeOverlay()
        case .undo:
            undoFromOutcomeOverlay()
        }
    }

    /// Keeps router confirm and overlay Tab-focus aligned.
    func setFocusedOutcomeAction(_ action: OutcomeFocusedAction) {
        focusedOutcomeAction = action
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

    // MARK: - Private bootstrap

    private func bootstrapFromPersistence() {
        switch runPersistence.load() {
        case .absent:
            startLevel(id: SokobanLevelCatalog.first.id, showIntro: true)

        case .loaded(let file):
            do {
                let restored = try SokobanRunRestorer.restore(file)
                let newSession = GameSession(restored: restored, saveSink: runPersistence)
                guard let descriptor = SokobanLevelCatalog.descriptor(id: restored.levelID) else {
                    enterRunRecovery(message: "Saved level is no longer in the catalog.")
                    return
                }
                cancelOutcomeWait()
                audioDirector.reset()
                scene.prepareForNewSession()
                // Mid-run restore skips the intro; the player already knows the level.
                bootstrapSession(newSession, descriptor: descriptor, showIntro: false)
            } catch {
                let message = restoreFailureMessage(error)
                _ = runPersistence.quarantineLoadedInvalidFile(message: message)
                enterRunRecovery(message: message)
            }

        case .invalid(let message, _):
            enterRunRecovery(message: message)

        case .readFailed(let message):
            // Do not move the file; still allow a fresh start via recovery UI.
            enterRunRecovery(message: message)
        }
    }

    private func bootstrapSession(
        _ newSession: GameSession,
        descriptor: SokobanLevelDescriptor,
        showIntro: Bool
    ) {
        let emission = newSession.start()
        session = newSession
        currentLevelID = descriptor.id
        faultMessage = nil
        recoveryMessage = nil
        levelTitle = descriptor.title
        tutorialHintText = AppStrings.text(id: descriptor.tutorialHintID)
        configureOutcomeActions(for: descriptor.id)
        scene.apply(emission.render)
        audioDirector.apply(emission.audio)
        applyEmissionSideEffects(emission)
        // Restored/completed runs use synchronize (no completion jingle).
        if newSession.phase == .outcomePresenting {
            // Hard-resync has no animation; land on the choice overlay promptly.
            enterOutcomeAwaitingChoice()
        } else if showIntro {
            enterLevelIntro()
        } else {
            presentationPhase = .playing
            router.enterGameplay()
        }
        refreshPublishedState()
    }

    private func enterLevelIntro() {
        presentationPhase = .levelIntro
        router.enterLevelIntro()
    }

    private func configureOutcomeActions(for levelID: String) {
        if let next = SokobanLevelCatalog.descriptor(after: levelID) {
            outcomePrimaryAction = .nextLevel(id: next.id)
            outcomePrimaryTitle = AppStrings.text(.uiOutcomeNextLevel)
            outcomeTitle = AppStrings.text(.uiOutcomeLevelComplete)
            outcomeHint = AppStrings.text(.uiOutcomeHintNext)
        } else {
            outcomePrimaryAction = .finishTutorial
            outcomePrimaryTitle = AppStrings.text(.uiOutcomeBack)
            outcomeTitle = AppStrings.text(.uiOutcomeTutorialComplete)
            outcomeHint = AppStrings.text(.uiOutcomeHintBack)
        }
    }

    private func enterRunRecovery(message: String) {
        session = nil
        presentationPhase = .runRecovery
        recoveryMessage = message
        faultMessage = nil
        router.enterModalBlocked()
        audioDirector.reset()
        refreshPublishedState()
    }

    private func restoreFailureMessage(_ error: Error) -> String {
        if let failure = error as? SokobanRunRestoreFailure {
            switch failure {
            case .unknownSchemaVersion(let version):
                return "Run file schema version \(version) is not supported."
            case .unknownCheckpointSchemaVersion(let version):
                return "Checkpoint schema version \(version) is not supported."
            case .unknownLevelID(let id):
                return "Saved level “\(id)” is unknown."
            case .contentHashMismatch:
                return "Saved level content no longer matches this build."
            case .ruleVersionMismatch(let found, let expected):
                return "Rule version \(found) is incompatible (expected \(expected))."
            case .tooManyCommands(let count):
                return "Run file has too many commands (\(count))."
            case .cursorOutOfRange(let cursor, let count):
                return "Run file cursor \(cursor) is outside 0...\(count)."
            case .checkpointInvalid(let detail):
                return "Saved checkpoint is invalid: \(detail)"
            case .commandBlockedDuringReplay(let index):
                return "Saved move \(index) is blocked and cannot be replayed."
            case .commandAfterTerminal(let index):
                return "Saved move \(index) appears after the level already finished."
            case .engineFault(let detail):
                return "Could not restore run: \(detail)"
            }
        }
        return "Could not restore run: \(error.localizedDescription)"
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
            skipOutcomePresentation()
        case .outcomeAwaitingChoice:
            performFocusedOutcomeAction()
        default:
            break
        }
    }

    private func pauseFromShell(alreadyInterrupted: Bool = false) {
        guard let session, session.phase == .playing else { return }
        session.pause()
        if !alreadyInterrupted {
            audioDirector.interrupt()
        }
        router.enterPaused()
        presentationPhase = .paused
        refreshPublishedState()
    }

    private func resumeFromShell() {
        guard let session, session.phase == .paused else { return }
        session.resume()
        audioDirector.resumePlayback()
        router.enterGameplay()
        presentationPhase = .playing
        refreshPublishedState()
    }

    private func resumeIfPaused() {
        guard let session, session.phase == .paused else { return }
        session.resume()
        audioDirector.resumePlayback()
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
                audioDirector.apply(emission.audio)
                applyEmissionSideEffects(emission)

            case .faulted(let message):
                cancelOutcomeWait()
                presentationPhase = .faulted
                faultMessage = message
                router.enterModalBlocked()
                scene.discardPendingPresentation()
                audioDirector.reset()
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
                // Keep intro until the player dismisses it; restart from intro dismisses first.
                if presentationPhase != .levelIntro {
                    presentationPhase = .playing
                    if router.mode != .gameplay {
                        router.enterGameplay()
                    }
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
        focusedOutcomeAction = .primary
        configureOutcomeActions(for: currentLevelID)
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
            canRestart = presentationPhase == .runRecovery
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
