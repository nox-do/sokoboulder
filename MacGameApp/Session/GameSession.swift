import GameCore

/// `@MainActor` owner of Sokoban run state, history, input queue, and revision.
///
/// The renderer and audio director never call ``SokobanRules`` directly.
/// Movement enters only via ``enqueueMove`` / ``processPendingMoves``.
@MainActor
final class GameSession {
    static let moveQueueLimit = 2
    static let historyLimit = 1_000

    private let rules = SokobanRules()
    private let levelID: String

    private var state: SokobanState
    private var initialState: SokobanState
    private var undoStack: [SokobanState] = []
    private var redoStack: [SokobanState] = []
    private var pendingMoves: [Direction] = []

    private(set) var revision: UInt64 = 0
    private(set) var phase: SessionPhase = .created

    /// Emission produced by ``start()`` — always a hard-resync, optionally outcome.
    private(set) var bootstrapEmission: SessionEmission?

    init(level: SokobanLevel, levelID: String = "untitled") throws {
        self.levelID = levelID
        let started = try SokobanRules().start(level: level)
        self.state = started
        self.initialState = started
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
        return emission
    }

    var undoCount: Int { undoStack.count }
    var redoCount: Int { redoStack.count }
    var pendingMoveCount: Int { pendingMoves.count }

    /// Enqueues a move when under the FIFO limit. Does not process it.
    ///
    /// This is the only public movement entry point.
    @discardableResult
    func enqueueMove(_ direction: Direction) -> Bool {
        guard isAcceptingGameplay else { return false }
        guard pendingMoves.count < Self.moveQueueLimit else { return false }
        pendingMoves.append(direction)
        return true
    }

    /// Processes all pending moves in FIFO order. Stops after a fault.
    func processPendingMoves() -> [SessionApplyResult] {
        guard isAcceptingGameplay else {
            pendingMoves.removeAll(keepingCapacity: true)
            return []
        }

        var results: [SessionApplyResult] = []
        while !pendingMoves.isEmpty {
            let direction = pendingMoves.removeFirst()
            let result = applyMove(direction)
            results.append(result)
            if case .faulted = result {
                pendingMoves.removeAll(keepingCapacity: true)
                break
            }
        }
        return results
    }

    /// Applies undo / redo / restart. Clears any pending move queue first.
    func apply(_ command: SessionCommand) -> SessionApplyResult {
        guard isAcceptingGameplay else { return .ignored }

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

    // MARK: - Private

    private var isAcceptingGameplay: Bool {
        switch phase {
        case .playing, .outcomePresenting:
            true
        case .created, .faulted:
            false
        }
    }

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

        switch transition.outcome {
        case .changed, .terminal:
            pushUndo(previous)
            redoStack.removeAll(keepingCapacity: true)
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

    private func applyUndo() -> SessionApplyResult {
        guard let restored = undoStack.popLast() else { return .ignored }
        redoStack.append(state)
        trimHistory(&redoStack)
        state = restored

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
        undoStack.append(state)
        trimHistory(&undoStack)
        state = restored

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
        state = initialState

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

    private func pushUndo(_ previous: SokobanState) {
        undoStack.append(previous)
        trimHistory(&undoStack)
    }

    private func trimHistory(_ stack: inout [SokobanState]) {
        if stack.count > Self.historyLimit {
            stack.removeFirst(stack.count - Self.historyLimit)
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
    #endif
}
