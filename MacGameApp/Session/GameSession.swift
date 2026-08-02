import GameCore

/// Narrow sink used by ``GameSession``; write generations live in persistence.
@MainActor
protocol SokobanRunSaveSink: AnyObject {
    func scheduleSave(_ file: SokobanRunFileV1)
}

/// `@MainActor` owner of Sokoban run state, history, input queue, and revision.
///
/// The renderer and audio director never call ``SokobanRules`` directly.
/// Productive movement entry is ``submitMove(_:)``, which owns enqueue + drain.
/// Persistable journal lives here; the controller must not infer saves from render.
@MainActor
final class GameSession {
    static let moveQueueLimit = 2
    static let historyLimit = SokobanRunRestorer.commandLimit

    private let rules = SokobanRules()
    private let level: SokobanLevel
    private let levelID: String
    private let contentHash: String
    private let staticDeadSquares: Set<GridPosition>
    private weak var saveSink: SokobanRunSaveSink?

    private var state: SokobanState
    /// True level start — restart returns here even after checkpoint compaction.
    private var initialState: SokobanState
    private var checkpoint: SokobanCheckpoint
    private var journalCommands: [Direction] = []
    private var journalCursor: Int = 0
    private var undoStack: [SokobanState] = []
    private var redoStack: [SokobanState] = []
    private var pendingMoves: [Direction] = []

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
        self.level = level
        self.levelID = levelID
        self.contentHash = contentHash
        self.staticDeadSquares = SokobanStaticDeadlockAnalyzer.staticDeadSquares(in: level)
        self.saveSink = saveSink
        let started = try SokobanRules().start(level: level)
        self.state = started
        self.initialState = started
        self.checkpoint = SokobanRules().checkpoint(from: started)
    }

    /// Restored run after successful ``SokobanRunRestorer`` replay.
    init(
        restored: SokobanRunRestoreResult,
        saveSink: SokobanRunSaveSink? = nil
    ) {
        self.level = restored.level
        self.levelID = restored.levelID
        self.contentHash = restored.contentHash
        self.staticDeadSquares = SokobanStaticDeadlockAnalyzer.staticDeadSquares(in: restored.level)
        self.saveSink = saveSink
        self.state = restored.currentState
        self.initialState = restored.initialState
        self.checkpoint = restored.checkpoint
        self.journalCommands = restored.commands
        self.journalCursor = restored.cursor
        self.undoStack = restored.undoStack
        self.redoStack = restored.redoStack
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

    var undoCount: Int { undoStack.count }
    var redoCount: Int { redoStack.count }
    var pendingMoveCount: Int { pendingMoves.count }
    var journalCommandCount: Int { journalCommands.count }
    var journalCursorValue: Int { journalCursor }

    /// Moves are accepted only while actively playing (not paused / outcome / fault).
    var canAcceptMove: Bool { phase == .playing }

    /// Undo, redo, and restart stay available during outcome presentation.
    var canAcceptSessionCommand: Bool {
        switch phase {
        case .playing, .outcomePresenting:
            true
        case .created, .paused, .faulted:
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

    /// Productive movement facade: enqueue then drain the Sokoban queue immediately.
    ///
    /// Rejects when ``canAcceptMove`` is false. Returns every ordered apply result
    /// from the drain. Does not wait on animation or render frames.
    @discardableResult
    func submitMove(_ direction: Direction) -> [SessionApplyResult] {
        guard enqueueMove(direction) else { return [] }
        return processPendingMoves()
    }

    /// Enqueues a move when under the FIFO limit. Does not process it.
    ///
    /// Prefer ``submitMove(_:)`` in production. Visible for tests and internal use.
    @discardableResult
    func enqueueMove(_ direction: Direction) -> Bool {
        guard canAcceptMove else { return false }
        guard pendingMoves.count < Self.moveQueueLimit else { return false }
        pendingMoves.append(direction)
        return true
    }

    /// Processes pending moves in FIFO order.
    ///
    /// Stops and discards the remainder after a fault or after entering
    /// ``SessionPhase/outcomePresenting``. Prefer ``submitMove(_:)`` in production.
    func processPendingMoves() -> [SessionApplyResult] {
        var results: [SessionApplyResult] = []
        while !pendingMoves.isEmpty {
            guard phase == .playing else {
                pendingMoves.removeAll(keepingCapacity: true)
                break
            }

            let direction = pendingMoves.removeFirst()
            let result = applyMove(direction)
            results.append(result)

            switch result {
            case .faulted:
                pendingMoves.removeAll(keepingCapacity: true)
                return results
            case .emitted, .ignored:
                if phase != .playing {
                    pendingMoves.removeAll(keepingCapacity: true)
                    return results
                }
            }
        }
        return results
    }

    /// Applies undo / redo / restart. Clears any pending move queue first.
    func apply(_ command: SessionCommand) -> SessionApplyResult {
        guard canAcceptSessionCommand else { return .ignored }

        pendingMoves.removeAll(keepingCapacity: true)

        switch command {
        case .undo:
            return applyUndo()
        case .redo:
            return applyRedo()
        case .restart:
            return applyRestart()
        }
    }

    /// Shell interruption: clear the move queue and reject further moves.
    ///
    /// Does not mutate the authoritative Sokoban core state. Focus loss uses the
    /// same path. Only transitions ``playing`` → ``paused``.
    func pause() {
        pendingMoves.removeAll(keepingCapacity: true)
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
        pendingMoves.removeAll(keepingCapacity: true)
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
            transition = try rules.move(direction, in: state)
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

        if events.contains(where: { event in
            if case .objectPushed = event { return true }
            return false
        }), containsCrateOnStaticDeadSquare(in: next) {
            preventedStaticDeadlockOnLastMove = true
            return .emitted(
                makeEmission(
                    events: [.movementBlocked(at: previous.playerPosition)],
                    delivery: .animate,
                    audioDelivery: .perform,
                    appTransition: nil
                )
            )
        }

        switch transition.outcome {
        case .changed, .terminal:
            recordChangingMove(direction, previous: previous)
        case .blocked:
            break
        }

        state = next

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

    private func recordChangingMove(_ direction: Direction, previous: SokobanState) {
        if journalCursor < journalCommands.count {
            journalCommands.removeSubrange(journalCursor...)
        }
        journalCommands.append(direction)
        journalCursor = journalCommands.count

        undoStack.append(previous)
        redoStack.removeAll(keepingCapacity: true)

        compactJournalIfNeeded()
        persistRun()
    }

    private func containsCrateOnStaticDeadSquare(in candidate: SokobanState) -> Bool {
        staticDeadSquares.contains { position in
            if case .crate = candidate.grid[position].occupant { return true }
            return false
        }
    }

    private func applyUndo() -> SessionApplyResult {
        guard let restored = undoStack.popLast() else { return .ignored }
        guard journalCursor > 0 else { return .ignored }

        redoStack.append(state)
        journalCursor -= 1
        state = restored
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
        guard let restored = redoStack.popLast() else { return .ignored }
        guard journalCursor < journalCommands.count else { return .ignored }

        undoStack.append(state)
        journalCursor += 1
        state = restored
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
        undoStack.removeAll(keepingCapacity: true)
        redoStack.removeAll(keepingCapacity: true)
        journalCommands.removeAll(keepingCapacity: true)
        journalCursor = 0
        checkpoint = rules.checkpoint(from: initialState)
        state = initialState
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

    /// Advances the checkpoint by the oldest command when the journal exceeds the limit.
    private func compactJournalIfNeeded() {
        while journalCommands.count > Self.historyLimit {
            let oldest = journalCommands.removeFirst()
            do {
                let before = try rules.restore(level: level, checkpoint: checkpoint)
                let transition = try rules.move(oldest, in: before)
                switch transition.outcome {
                case .changed, .terminal:
                    checkpoint = rules.checkpoint(from: transition.state)
                case .blocked:
                    // Should be unreachable for a journal of applied commands.
                    phase = .faulted
                    return
                }
            } catch {
                phase = .faulted
                return
            }

            if !undoStack.isEmpty {
                undoStack.removeFirst()
            }
            journalCursor = max(0, journalCursor - 1)
        }
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
            context: AudioContext(levelID: levelID, status: state.status),
            events: audioDelivery == .perform ? events : [],
            delivery: audioDelivery
        )
        return SessionEmission(render: render, audio: audio, appTransition: appTransition)
    }

    #if DEBUG
    /// Test-only: replace state to exercise ``EngineFault`` handling.
    func replaceStateForTesting(_ newState: SokobanState) {
        state = newState
    }

    /// Test-only: inspect checkpoint after compaction.
    var checkpointForTesting: SokobanCheckpoint { checkpoint }
    #endif
}
