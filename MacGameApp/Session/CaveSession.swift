import Foundation
import GameCore

/// Tick-driven cave session: Ready → first intent = Tick 1, then fixed-step catch-up.
///
/// Follows ADR 0005 / ARCHITECTURE §8.2 in a playable form: accumulator + catch-up,
/// hard-resync emissions, no run persistence.
@MainActor
final class CaveSession {
    static let maxCatchUpTicks = 5

    private let rules = CaveRules()
    private let level: CaveLevel
    private let levelID: String

    private var state: CaveState
    private var initialState: CaveState

    private(set) var revision: UInt64 = 0
    private(set) var phase: SessionPhase = .created

    private var accumulator: TimeInterval = 0
    private var lastAdvanceTime: TimeInterval?
    /// First intent waiting to leave Ready (consumed exactly once as Tick 1).
    private var readyIntent: CaveInput?
    private var heldDirections: [Direction] = []
    private var pressLatch: Direction?
    private var pendingWait = false

    private(set) var bootstrapEmission: SessionEmission?

    var fixedStep: TimeInterval { CaveRules.fixedStepSeconds }

    init(level: CaveLevel, levelID: String = "cave.demo.001") throws {
        self.level = level
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
        heldDirections.removeAll { $0 == direction }
        heldDirections.append(direction)
        pressLatch = direction
        if phase == .ready {
            readyIntent = .move(direction)
        }
    }

    func noteDirectionUp(_ direction: Direction) {
        heldDirections.removeAll { $0 == direction }
    }

    func noteWait() {
        guard canAcceptInput else { return }
        pendingWait = true
        if phase == .ready {
            readyIntent = .wait
        }
    }

    func clearInputState() {
        heldDirections = []
        pressLatch = nil
        pendingWait = false
        readyIntent = nil
    }

    /// Advances simulation using the shared monotonic clock reading `now`.
    ///
    /// In Ready, returns an emission only when a first intent is pending (Tick 1).
    /// While playing, catches up at most ``maxCatchUpTicks`` and emits one update.
    func advance(to now: TimeInterval) -> SessionEmission? {
        switch phase {
        case .ready:
            guard let intent = readyIntent else { return nil }
            readyIntent = nil
            phase = .playing
            lastAdvanceTime = now
            accumulator = 0
            pressLatch = nil
            pendingWait = false
            return runTick(input: intent)
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
        var terminalStatus: PlayStatus?

        while accumulator >= fixedStep && ticksRun < Self.maxCatchUpTicks {
            accumulator -= fixedStep
            let input = resolveTickInput()
            do {
                let transition = try rules.tick(input: input, state: state)
                state = transition.state
                aggregatedEvents.append(contentsOf: transition.events)
                ticksRun += 1
                if case .terminal(let status) = transition.outcome {
                    terminalStatus = status
                    break
                }
            } catch {
                phase = .faulted
                clearInputState()
                accumulator = 0
                return nil
            }
        }

        if ticksRun == Self.maxCatchUpTicks, accumulator >= fixedStep {
            // Discard leftover wall time; keep global simulation tick (state.tick).
            accumulator = 0
        }

        guard ticksRun > 0 else { return nil }

        if let terminalStatus {
            phase = .outcomePresenting
            clearInputState()
            return makeEmission(
                events: aggregatedEvents,
                delivery: .hardResync,
                // Play death / win / exit cues; music still stops via completed/failed status.
                audioDelivery: .perform,
                appTransition: .enterOutcomePresenting
            )
        }

        return makeEmission(
            events: aggregatedEvents,
            delivery: .hardResync,
            audioDelivery: .perform,
            appTransition: nil
        )
    }

    func pause() {
        guard phase == .playing || phase == .ready else { return }
        phase = .paused
        clearInputState()
        accumulator = 0
        lastAdvanceTime = nil
        readyIntent = nil
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

    private func runTick(input: CaveInput) -> SessionEmission {
        do {
            let transition = try rules.tick(input: input, state: state)
            state = transition.state
            if case .terminal = transition.outcome {
                phase = .outcomePresenting
                clearInputState()
                return makeEmission(
                    events: transition.events,
                    delivery: .hardResync,
                    audioDelivery: .perform,
                    appTransition: .enterOutcomePresenting
                )
            }
            return makeEmission(
                events: transition.events,
                delivery: .hardResync,
                audioDelivery: .perform,
                appTransition: nil
            )
        } catch {
            phase = .faulted
            clearInputState()
            return makeEmission(
                events: [],
                delivery: .hardResync,
                audioDelivery: .synchronize,
                appTransition: nil
            )
        }
    }

    private func resolveTickInput() -> CaveInput {
        if pendingWait {
            pendingWait = false
            pressLatch = nil
            return .wait
        }
        if let latch = pressLatch {
            pressLatch = nil
            return .move(latch)
        }
        if let held = heldDirections.last {
            return .move(held)
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
        let renderEvents = delivery == .hardResync ? [] : events
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
