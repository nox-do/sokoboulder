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
        levelID: String = "test.level",
        game: AudioGameMode = .sokoban
    ) -> AudioContext {
        AudioContext(game: game, levelID: levelID, status: status)
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
        #expect(spy.playedEffects == [.movementStep])
        #expect(spy.musicStates == [.themeLoop])
    }

    @Test("push maps to objectPushed without a step cue")
    func pushDoesNotAlsoPlayStep() {
        #expect(
            AudioDirector.cues(from: [cratePushed(), playerMoved()]) == [.objectPushed]
        )
        #expect(AudioDirector.cues(from: [playerMoved()]) == [.movementStep])
        #expect(
            AudioDirector.cues(from: [
                .movementBlocked(at: GridPosition(column: 0, row: 0)),
            ]) == [.movementBlocked]
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
            ]) == [.collectiblePickedUp, .objectiveCompleted]
        )
    }

    @Test("cave events map to dedicated cues without fall-start spam")
    func caveEventCueMapping() {
        let diamond = EntityRef(id: EntityID(2), kind: .diamond)
        #expect(
            AudioDirector.cues(from: [
                .diamondCollected(diamond, at: GridPosition(column: 1, row: 1), total: 1),
                .exitOpened(at: GridPosition(column: 2, row: 1)),
            ]) == [.collectiblePickedUp, .exitOpened]
        )
        #expect(
            AudioDirector.cues(from: [
                .playerDied(at: GridPosition(column: 1, row: 1)),
                .timeExpired,
            ]) == [.playerDied]
        )
        #expect(
            AudioDirector.cues(from: [
                .objectStartedFalling(diamond, at: GridPosition(column: 1, row: 0)),
                .objectLanded(diamond, at: GridPosition(column: 1, row: 1)),
                .levelCompleted,
            ]) == [.objectLanded, .objectiveCompleted]
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
        #expect(spy.musicStates == [.themeLoop])
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
        #expect(spy.playedEffects == [.objectPushed, .objectiveCompleted])
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
        #expect(spy.musicStates == [.themeLoop])
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
        #expect(spy.musicStates == [.themeLoop])
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
        #expect(!spy.musicStates.contains(.themeLoop))
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

    @Test("completed perform plays jingle and soft-fades BGM immediately")
    func completedFadesMusicUnderJingle() {
        #expect(
            AudioDirector.musicState(for: context(status: .completed)) == .stopped
        )
        #expect(
            AudioDirector.musicState(for: context(status: .playing)) == .themeLoop
        )

        let (director, spy) = makeDirector()
        director.apply(update(revision: 1, delivery: .synchronize))
        spy.resetCalls()
        director.apply(
            update(
                revision: 2,
                delivery: .perform,
                events: [.levelCompleted],
                status: .completed
            )
        )
        #expect(spy.playedEffects == [.objectiveCompleted])
        #expect(spy.musicStates == [.stopped])
        #expect(spy.musicFadeDurations == [AudioDirector.winMusicFadeOut])
    }

    @Test("completed synchronize still stops music immediately (restored run)")
    func completedSynchronizeStopsMusicImmediately() {
        let (director, spy) = makeDirector()
        director.apply(update(revision: 1, delivery: .synchronize))
        spy.resetCalls()
        director.apply(
            update(revision: 2, delivery: .synchronize, events: [], status: .completed)
        )
        #expect(spy.musicStates == [.stopped])
        #expect(spy.musicFadeDurations == [0])
    }
}
