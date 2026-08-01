import Testing
@testable import GameCore
@testable import MacGameApp

@Suite("AudioDirector revision contract")
@MainActor
struct AudioDirectorTests {
    private func makeDirector() -> (AudioDirector, SpyAudioPlaybackBackend) {
        let spy = SpyAudioPlaybackBackend()
        return (AudioDirector(backend: spy), spy)
    }

    private func context(
        status: PlayStatus = .playing,
        levelID: String = "test.level"
    ) -> AudioContext {
        AudioContext(levelID: levelID, status: status)
    }

    private func update(
        revision: UInt64,
        delivery: AudioDelivery,
        events: [GameEvent] = [],
        status: PlayStatus = .playing
    ) -> AudioUpdate {
        AudioUpdate(
            targetRevision: revision,
            context: context(status: status),
            events: events,
            delivery: delivery
        )
    }

    private func playerMoved() -> GameEvent {
        .entityMoved(
            EntityRef(id: EntityID(1), kind: .player),
            from: GridPosition(column: 1, row: 1),
            to: GridPosition(column: 2, row: 1)
        )
    }

    private func cratePushed() -> GameEvent {
        .objectPushed(
            EntityRef(id: EntityID(2), kind: .crate),
            from: GridPosition(column: 2, row: 1),
            to: GridPosition(column: 3, row: 1)
        )
    }

    @Test("perform plays cues once and aligns music to the same revision")
    func performPlaysOnce() {
        let (director, spy) = makeDirector()
        director.apply(update(revision: 1, delivery: .synchronize))
        spy.resetCalls()

        director.apply(
            update(
                revision: 2,
                delivery: .perform,
                events: [playerMoved()]
            )
        )

        #expect(director.lastAppliedRevision == 2)
        #expect(spy.playedEffects == [.step])
        #expect(spy.musicStates == [.sokobanLoop])
    }

    @Test("push maps to cratePushed without a step cue")
    func pushDoesNotAlsoPlayStep() {
        #expect(
            AudioDirector.cues(from: [cratePushed(), playerMoved()]) == [.cratePushed]
        )
        #expect(AudioDirector.cues(from: [playerMoved()]) == [.step])
        #expect(
            AudioDirector.cues(from: [
                .movementBlocked(at: GridPosition(column: 0, row: 0)),
            ]) == [.blocked]
        )
        #expect(
            AudioDirector.cues(from: [
                .crateEnteredGoal(
                    EntityRef(id: EntityID(2), kind: .crate),
                    at: GridPosition(column: 1, row: 1),
                    completed: 1,
                    total: 1
                ),
                .levelCompleted,
            ]) == [.goalEntered, .levelCompleted]
        )
    }

    @Test("synchronize never replays transient events and cuts running effects")
    func synchronizeSkipsEvents() {
        let (director, spy) = makeDirector()
        director.apply(update(revision: 1, delivery: .synchronize))
        director.apply(
            update(
                revision: 2,
                delivery: .perform,
                events: [.levelCompleted],
                status: .completed
            )
        )
        spy.resetCalls()

        director.apply(
            update(
                revision: 3,
                delivery: .synchronize,
                events: [playerMoved(), .levelCompleted],
                status: .playing
            )
        )

        #expect(spy.playedEffects.isEmpty)
        #expect(spy.calls.contains(.stopAllEffects))
        #expect(spy.musicStates == [.sokobanLoop])
        #expect(director.lastAppliedRevision == 3)
    }

    @Test("duplicate revision drops cues and music updates")
    func duplicateDrops() {
        let (director, spy) = makeDirector()
        director.apply(update(revision: 1, delivery: .synchronize))
        director.apply(
            update(revision: 2, delivery: .perform, events: [playerMoved()])
        )
        spy.resetCalls()

        director.apply(
            update(revision: 2, delivery: .perform, events: [playerMoved()])
        )

        #expect(spy.calls.isEmpty)
        #expect(director.lastAppliedRevision == 2)
    }

    @Test("stale older revision is discarded and does not rewind tracking")
    func staleOlderRevisionDiscarded() {
        let (director, spy) = makeDirector()
        director.apply(update(revision: 1, delivery: .synchronize))
        director.apply(update(revision: 2, delivery: .synchronize))
        director.apply(update(revision: 3, delivery: .synchronize))
        director.apply(update(revision: 4, delivery: .synchronize))
        spy.resetCalls()

        director.apply(
            update(
                revision: 3,
                delivery: .perform,
                events: [playerMoved(), .levelCompleted]
            )
        )
        #expect(spy.calls.isEmpty)
        #expect(director.lastAppliedRevision == 4)

        director.apply(
            update(
                revision: 4,
                delivery: .perform,
                events: [playerMoved()]
            )
        )
        #expect(spy.calls.isEmpty)
        #expect(director.lastAppliedRevision == 4)
    }

    @Test("forward revision gap ignores events, cuts effects, and aligns music")
    func gapIgnoresEvents() {
        let (director, spy) = makeDirector()
        director.apply(update(revision: 1, delivery: .synchronize))
        spy.resetCalls()

        director.apply(
            update(
                revision: 4,
                delivery: .perform,
                events: [playerMoved(), .levelCompleted],
                status: .completed
            )
        )

        #expect(spy.playedEffects.isEmpty)
        #expect(spy.calls.contains(.stopAllEffects))
        #expect(spy.musicStates == [.stopped])
        #expect(director.lastAppliedRevision == 4)
    }

    @Test("undo-style synchronize after perform does not replay old cues")
    func undoSynchronizeNoReplay() {
        let (director, spy) = makeDirector()
        director.apply(update(revision: 1, delivery: .synchronize))
        director.apply(
            update(
                revision: 2,
                delivery: .perform,
                events: [cratePushed(), playerMoved(), .levelCompleted],
                status: .completed
            )
        )
        #expect(spy.playedEffects == [.cratePushed, .levelCompleted])
        spy.resetCalls()

        director.apply(
            update(
                revision: 3,
                delivery: .synchronize,
                events: [],
                status: .playing
            )
        )

        #expect(spy.playedEffects.isEmpty)
        #expect(spy.calls.contains(.stopAllEffects))
        #expect(spy.musicStates == [.sokobanLoop])
    }

    @Test("interrupt stops voices; resume restores music without replaying cues")
    func interruptAndResume() {
        let (director, spy) = makeDirector()
        director.apply(update(revision: 1, delivery: .synchronize))
        director.apply(
            update(revision: 2, delivery: .perform, events: [playerMoved()])
        )
        spy.resetCalls()

        director.interrupt()
        #expect(spy.calls.contains(.stopAllEffects))
        #expect(spy.musicStates.last == .stopped)

        spy.resetCalls()
        director.resumePlayback()
        #expect(spy.playedEffects.isEmpty)
        #expect(spy.musicStates == [.sokobanLoop])
    }

    @Test("perform while interrupted stores revision but plays nothing")
    func interruptedPerformIsSilent() {
        let (director, spy) = makeDirector()
        director.apply(update(revision: 1, delivery: .synchronize))
        director.interrupt()
        spy.resetCalls()

        director.apply(
            update(revision: 2, delivery: .perform, events: [playerMoved()])
        )

        #expect(director.lastAppliedRevision == 2)
        #expect(spy.playedEffects.isEmpty)
        #expect(!spy.musicStates.contains(.sokobanLoop))
    }

    @Test("reset clears revision tracking and stops playback")
    func resetClearsState() {
        let (director, spy) = makeDirector()
        director.apply(update(revision: 1, delivery: .synchronize))
        director.apply(
            update(revision: 2, delivery: .perform, events: [playerMoved()])
        )
        spy.resetCalls()

        director.reset()
        #expect(director.lastAppliedRevision == nil)
        #expect(spy.calls == [.stopAll])
    }

    @Test("completed context stops music")
    func completedStopsMusic() {
        #expect(
            AudioDirector.musicState(for: context(status: .completed)) == .stopped
        )
        #expect(
            AudioDirector.musicState(for: context(status: .playing)) == .sokobanLoop
        )
    }
}
