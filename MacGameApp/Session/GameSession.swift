import GameCore

/// Narrow sink used by ``GameSession``; write generations live in persistence.
@MainActor
protocol SokobanRunSaveSink: AnyObject {
    func scheduleSave(_ file: SokobanRunFileV1)
}

/// `@MainActor` owner of Sokoban run state, history, and revision.
///
/// The renderer and audio director never call ``SokobanRules`` directly.
/// Productive movement entry is ``submitMove(_:)``, which applies one move immediately.
/// Persistable journal lives here; the controller must not infer saves from render.
@MainActor
final class GameSession {
    static let historyLimit = SokobanRunRestorer.commandLimit

    private let rules = SokobanRules()
    private let levelID: String
    private let contentHash: String
    private let staticDeadSquares: Set<GridPosition>
    private weak var saveSink: SokobanRunSaveSink?

    /// State zero is the checkpoint; command N leads to state N + 1.
    /// Undo and redo only move the cursor through this single timeline.
    private var history: [SokobanState]
    private var journalCommands: [Direction] = []
    private var journalCursor: Int = 0
    private var state: SokobanState { history[journalCursor] }
    private var checkpoint: SokobanCheckpoint { rules.checkpoint(from: history[0]) }
    /// True level start — restart returns here even after checkpoint compaction.
    private let initialState: SokobanState

    private(set) var revision: UInt64 = 0
    private(set) var phase: SessionPhase = .created
    private(set) var preventedStaticDeadlockOnLastMove = false

    /// Emission produced by ``start()`` — always a hard-resync, optionally outcome.
    private(set) var bootstrapEmission: SessionEmission?

    /// Fresh run at level start.
    init(
        level: SokobanLevel,
        levelID: String = "untitled",
        contentHash: String = "",
        saveSink: SokobanRunSaveSink? = nil
    ) throws {
        self.levelID = levelID
        self.contentHash = contentHash
        self.staticDeadSquares = SokobanStaticDeadlockAnalyzer.staticDeadSquares(in: level)
        self.saveSink = saveSink
        let started = try SokobanRules().start(level: level)
        self.history = [started]
        self.initialState = started
    }

    /// Restored run after successful ``SokobanRunRestorer`` replay.
    init(
        restored: SokobanRunRestoreResult,
        saveSink: SokobanRunSaveSink? = nil
    ) {
        self.levelID = restored.levelID
        self.contentHash = restored.contentHash
        self.staticDeadSquares = SokobanStaticDeadlockAnalyzer.staticDeadSquares(in: restored.level)
        self.saveSink = saveSink
        self.history = restored.undoStack + [restored.currentState] + restored.redoStack.reversed()
        self.initialState = restored.initialState
        self.journalCommands = restored.commands
        self.journalCursor = restored.cursor
    }

    /// Emits the initial hard-resync (revision 0 → 1). Call once after construction.
    @discardableResult
    func start() -> SessionEmission {
        precondition(phase == .created, "GameSession.start() must be called once from .created")
        precondition(bootstrapEmission == nil, "GameSession.start() must be called once")

        if state.status == .completed {
            phase = .outcomePresenting
        } else {
            phase = .playing
        }

        let transition: SessionAppTransition? =
            state.status == .completed ? .enterOutcomePresenting : nil
        let emission = makeEmission(
            events: [],
            delivery: .hardResync,
            audioDelivery: .synchronize,
            appTransition: transition
        )
        bootstrapEmission = emission
        persistRun()
        return emission
    }

    var undoCount: Int { journalCursor }
    var redoCount: Int { journalCommands.count - journalCursor }
    var journalCommandCount: Int { journalCommands.count }
    var journalCursorValue: Int { journalCursor }

    /// Moves are accepted only while actively playing (not paused / outcome / fault).
    var canAcceptMove: Bool { phase == .playing }

    /// Undo, redo, and restart stay available during outcome presentation.
    var canAcceptSessionCommand: Bool {
        switch phase {
        case .playing, .outcomePresenting:
            true
        case .created, .ready, .paused, .faulted:
            false
        }
    }

    /// Immutable run snapshot for the current journal / checkpoint.
    func makeRunFile() throws -> SokobanRunFileV1 {
        SokobanRunFileV1(
            schemaVersion: SokobanRunFileV1.currentSchemaVersion,
            levelID: levelID,
            contentHash: contentHash,
            ruleVersion: SokobanRules.ruleVersion,
            checkpoint: try SokobanCheckpointV1(semantic: checkpoint),
            commands: journalCommands.map(SokobanDirectionV1.init),
            cursor: journalCursor
        )
    }

    /// Applies one move immediately, independently of animation or render frames.
    @discardableResult
    func submitMove(_ direction: Direction) -> SessionApplyResult {
        guard canAcceptMove else { return .ignored }
        return applyMove(direction)
    }

    /// Applies undo / redo / restart.
    func apply(_ command: SessionCommand) -> SessionApplyResult {
        guard canAcceptSessionCommand else { return .ignored }

        switch command {
        case .undo:
            return applyUndo()
        case .redo:
            return applyRedo()
        case .restart:
            return applyRestart()
        }
    }

    /// Shell interruption: reject further moves.
    ///
    /// Does not mutate the authoritative Sokoban core state. Focus loss uses the
    /// same path. Only transitions ``playing`` → ``paused``.
    func pause() {
        guard phase == .playing else { return }
        phase = .paused
    }

    /// Ends a ``pause()`` interruption and accepts moves again.
    func resume() {
        guard phase == .paused else { return }
        phase = .playing
    }

    // MARK: - Private

    /// Marks the session faulted without emitting render/audio updates (§16).
    private func fail(_ fault: EngineFault) -> SessionApplyResult {
        phase = .faulted
        let message: String
        switch fault {
        case .invariantViolated(let detail):
            message = detail
        }
        return .faulted(message: message)
    }

    private func applyMove(_ direction: Direction) -> SessionApplyResult {
        preventedStaticDeadlockOnLastMove = false
        let transition: Transition<SokobanState>
        do {
            transition = try rules.move(direction, in: state, avoidingStaticDeadSquares: staticDeadSquares)
        } catch {
            return fail(error)
        }

        let previous = state
        let next = transition.state
        let events = transition.events

        // Empty terminal / no-op: no events and identical state → no revision.
        if events.isEmpty, next == previous {
            return .ignored
        }

        preventedStaticDeadlockOnLastMove = transition.blockReason == .staticDeadlock

        switch transition.outcome {
        case .changed, .terminal:
            recordChangingMove(direction, next: next)
        case .blocked:
            break
        }

        var appTransition: SessionAppTransition?
        if case .terminal(.completed) = transition.outcome {
            phase = .outcomePresenting
            appTransition = .enterOutcomePresenting
        }

        return .emitted(
            makeEmission(
                events: events,
                delivery: .animate,
                audioDelivery: .perform,
                appTransition: appTransition
            )
        )
    }

    private func recordChangingMove(_ direction: Direction, next: SokobanState) {
        journalCommands.removeSubrange(journalCursor...)
        history.removeSubrange((journalCursor + 1)...)
        journalCommands.append(direction)
        history.append(next)
        journalCursor += 1

        let excess = max(0, journalCommands.count - Self.historyLimit)
        if excess > 0 {
            journalCommands.removeFirst(excess)
            history.removeFirst(excess)
            journalCursor -= excess
        }
        persistRun()
    }

    private func applyUndo() -> SessionApplyResult {
        guard journalCursor > 0 else { return .ignored }

        journalCursor -= 1
        persistRun()

        let transition: SessionAppTransition?
        if phase == .outcomePresenting, state.status == .playing {
            phase = .playing
            transition = .returnToPlaying
        } else {
            transition = nil
        }

        return .emitted(
            makeEmission(
                events: [],
                delivery: .hardResync,
                audioDelivery: .synchronize,
                appTransition: transition
            )
        )
    }

    private func applyRedo() -> SessionApplyResult {
        guard journalCursor < journalCommands.count else { return .ignored }

        journalCursor += 1
        persistRun()

        var appTransition: SessionAppTransition?
        if state.status == .completed, phase != .outcomePresenting {
            phase = .outcomePresenting
            appTransition = .enterOutcomePresenting
        }

        return .emitted(
            makeEmission(
                events: [],
                delivery: .hardResync,
                audioDelivery: .synchronize,
                appTransition: appTransition
            )
        )
    }

    private func applyRestart() -> SessionApplyResult {
        let wasOutcome = phase == .outcomePresenting
        history = [initialState]
        journalCommands.removeAll(keepingCapacity: true)
        journalCursor = 0
        persistRun()

        let transition: SessionAppTransition?
        if state.status == .completed {
            phase = .outcomePresenting
            transition = .enterOutcomePresenting
        } else {
            phase = .playing
            transition = wasOutcome ? .returnToPlaying : nil
        }

        return .emitted(
            makeEmission(
                events: [],
                delivery: .hardResync,
                audioDelivery: .synchronize,
                appTransition: transition
            )
        )
    }

    private func persistRun() {
        guard let saveSink else { return }
        do {
            try saveSink.scheduleSave(makeRunFile())
        } catch {
            // Encoding failure is a persistence diagnosis, not a session fault.
        }
    }

    private func makeEmission(
        events: [GameEvent],
        delivery: RenderDelivery,
        audioDelivery: AudioDelivery,
        appTransition: SessionAppTransition?
    ) -> SessionEmission {
        let base = revision
        let target = base + 1
        revision = target
        let snapshot = RenderSnapshot.project(state)
        let render = RenderUpdate(
            baseRevision: base,
            targetRevision: target,
            snapshot: snapshot,
            events: events,
            delivery: delivery
        )
        let audio = AudioUpdate(
            targetRevision: target,
            context: AudioContext(game: .sokoban, levelID: levelID, status: state.status),
            events: audioDelivery == .perform ? events : [],
            delivery: audioDelivery
        )
        return SessionEmission(render: render, audio: audio, appTransition: appTransition)
    }

    #if DEBUG
        /// Test-only: replace state to exercise ``EngineFault`` handling.
        func replaceStateForTesting(_ newState: SokobanState) {
            history[journalCursor] = newState
        }

        /// Test-only: inspect checkpoint after compaction.
        var checkpointForTesting: SokobanCheckpoint { checkpoint }
    #endif
}
