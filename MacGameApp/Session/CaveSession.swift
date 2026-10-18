import Foundation
import GameCore

/// Tick-driven cave session: Ready → first intent = Tick 1, then fixed-step catch-up.
///
/// Follows ADR 0005 / ARCHITECTURE §8.2 in a playable form: accumulator + catch-up,
/// hard-resync emissions, no run persistence.
@MainActor
final class CaveSession {
    private let rules = CaveRules()
    private let levelID: String

    private var state: CaveState
    private let initialState: CaveState

    private(set) var revision: UInt64 = 0
    private(set) var phase: SessionPhase = .created

    private var accumulator: TimeInterval = 0
    private var lastAdvanceTime: TimeInterval?
    /// Latest explicit input wins until the next tick, including the Ready tick.
    private var pendingInput: CaveInput?

    private(set) var bootstrapEmission: SessionEmission?

    var fixedStep: TimeInterval { CaveRules.fixedStepSeconds }

    init(level: CaveLevel, levelID: String = "cave.demo.001") throws {
        self.levelID = levelID
        let started = try CaveRules().start(level: level)
        self.state = started
        self.initialState = started
    }

    var canAcceptInput: Bool {
        switch phase {
        case .ready, .playing: true
        case .created, .paused, .outcomePresenting, .faulted: false
        }
    }

    var snapshot: RenderSnapshot { RenderSnapshot.project(state) }

    var collectedDiamonds: Int { state.collectedDiamonds }
    var requiredDiamonds: Int { state.requiredDiamonds }
    var remainingTicks: Int { state.remainingTicks }
    var score: Int { state.score }
    var status: PlayStatus { state.status }
    var simulationTick: UInt64 { state.tick }

    /// Bootstraps into ``SessionPhase/ready`` — no simulation ticks yet.
    @discardableResult
    func start() -> SessionEmission {
        precondition(phase == .created)
        precondition(bootstrapEmission == nil)
        phase = .ready
        let emission = makeEmission(
            events: [],
            delivery: .hardResync,
            audioDelivery: .synchronize,
            appTransition: nil
        )
        bootstrapEmission = emission
        return emission
    }

    func noteDirectionDown(_ direction: Direction) {
        guard canAcceptInput else { return }
        pendingInput = .move(direction)
    }

    func noteWait() {
        guard canAcceptInput else { return }
        pendingInput = .wait
    }

    func clearInputState() {
        pendingInput = nil
    }

    /// Advances simulation using the shared monotonic clock reading `now`.
    ///
    /// In Ready, returns an emission only when a first intent is pending (Tick 1).
    /// While playing, accepts at most 0.25 seconds of elapsed time and emits one update.
    func advance(to now: TimeInterval, heldDirection: Direction? = nil) throws(EngineFault) -> SessionEmission? {
        do {
            return try advanceSimulation(to: now, heldDirection: heldDirection)
        } catch {
            phase = .faulted
            clearInputState()
            accumulator = 0
            lastAdvanceTime = nil
            throw error
        }
    }

    private func advanceSimulation(
        to now: TimeInterval, heldDirection: Direction?
    ) throws(EngineFault) -> SessionEmission? {
        switch phase {
        case .ready:
            guard let intent = pendingInput else { return nil }
            clearInputState()
            phase = .playing
            lastAdvanceTime = now
            accumulator = 0
            let events = try runTick(input: intent)
            return tickEmission(events: events)
        case .playing:
            break
        case .created, .paused, .outcomePresenting, .faulted:
            return nil
        }

        let previous = lastAdvanceTime ?? now
        let rawDelta = now - previous
        lastAdvanceTime = now
        let delta = min(max(rawDelta, 0), 0.25)
        accumulator += delta

        var aggregatedEvents: [GameEvent] = []
        var ticksRun = 0
        while accumulator >= fixedStep {
            accumulator -= fixedStep
            aggregatedEvents.append(contentsOf: try runTick(input: resolveTickInput(heldDirection: heldDirection)))
            ticksRun += 1
            if phase == .outcomePresenting { break }
        }

        guard ticksRun > 0 else { return nil }

        return tickEmission(events: aggregatedEvents)
    }

    func pause() {
        guard phase == .playing || phase == .ready else { return }
        phase = .paused
        clearInputState()
        accumulator = 0
        lastAdvanceTime = nil
    }

    func resume() {
        guard phase == .paused else { return }
        // After pause, return to ready if never started; else playing with fresh epoch.
        phase = state.tick == 0 ? .ready : .playing
        accumulator = 0
        lastAdvanceTime = nil
    }

    @discardableResult
    func restart() -> SessionEmission {
        state = initialState
        phase = .ready
        clearInputState()
        accumulator = 0
        lastAdvanceTime = nil
        return makeEmission(
            events: [],
            delivery: .hardResync,
            audioDelivery: .synchronize,
            appTransition: .returnToPlaying
        )
    }

    // MARK: - Private

    private func runTick(input: CaveInput) throws(EngineFault) -> [GameEvent] {
        let transition = try rules.tick(input: input, state: state)
        state = transition.state
        if case .terminal = transition.outcome {
            phase = .outcomePresenting
            clearInputState()
        }
        return transition.events
    }

    private func tickEmission(events: [GameEvent]) -> SessionEmission {
        makeEmission(
            events: events,
            delivery: .hardResync,
            audioDelivery: .perform,
            appTransition: phase == .outcomePresenting ? .enterOutcomePresenting : nil
        )
    }

    private func resolveTickInput(heldDirection: Direction?) -> CaveInput {
        if let input = pendingInput {
            pendingInput = nil
            return input
        }
        if let heldDirection {
            return .move(heldDirection)
        }
        return .wait
    }

    private func makeEmission(
        events: [GameEvent],
        delivery: RenderDelivery,
        audioDelivery: AudioDelivery,
        appTransition: SessionAppTransition?
    ) -> SessionEmission {
        let base = revision
        revision += 1
        let snap = RenderSnapshot.project(state)
        // Cave always hard-resyncs tiles, but still forwards events so the scene
        // can play one-shot VFX (explosions). Audio uses the same event list.
        let renderEvents = events
        let audioEvents = audioDelivery == .perform ? events : []
        return SessionEmission(
            render: RenderUpdate(
                baseRevision: base,
                targetRevision: revision,
                snapshot: snap,
                events: renderEvents,
                delivery: delivery
            ),
            audio: AudioUpdate(
                targetRevision: revision,
                context: AudioContext(game: .cave, levelID: levelID, status: state.status),
                events: audioEvents,
                delivery: audioDelivery
            ),
            appTransition: appTransition
        )
    }
}
