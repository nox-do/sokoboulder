import Testing

@testable import GameCore
@testable import MacGameApp

@Suite("GameSession revision contract")
@MainActor
struct GameSessionRevisionTests {
    private func makeSession(
        _ ascii: String,
        levelID: String = "test.level"
    ) throws -> GameSession {
        let level = try SokobanLevelValidator.level(fromASCII: ascii)
        return try GameSession(level: level, levelID: levelID)
    }

    private func started(_ ascii: String) throws -> GameSession {
        let session = try makeSession(ascii)
        #expect(session.phase == .created)
        _ = session.start()
        return session
    }

    private func move(_ session: GameSession, _ direction: Direction) -> SessionApplyResult {
        session.submitMove(direction)
    }

    @Test("start emits hardResync and bumps revision once")
    func startHardResync() throws {
        let session = try makeSession(
            """
            #####
            #@$.#
            #####
            """
        )
        #expect(session.phase == .created)
        let emission = session.start()
        #expect(session.phase == .playing)
        #expect(emission.render.baseRevision == 0)
        #expect(emission.render.targetRevision == 1)
        #expect(emission.render.delivery == .hardResync)
        #expect(emission.audio.targetRevision == 1)
        #expect(emission.audio.delivery == .synchronize)
        #expect(emission.audio.events.isEmpty)
        #expect(session.revision == 1)
        #expect(emission.appTransition == nil)
    }

    @Test("already completed level starts into outcomePresenting")
    func alreadyCompletedBootstrap() throws {
        let session = try makeSession("#@*#")
        let emission = session.start()
        #expect(session.phase == .outcomePresenting)
        #expect(emission.appTransition == .enterOutcomePresenting)
        #expect(emission.render.snapshot.status == .completed)
    }

    @Test("commands before start are rejected")
    func rejectsBeforeStart() throws {
        let session = try makeSession(
            """
            #####
            #@$.#
            #####
            """
        )
        #expect(session.phase == .created)
        #expect(session.submitMove(.right) == .ignored)
        #expect(session.apply(.undo) == .ignored)
        #expect(session.apply(.redo) == .ignored)
        #expect(session.apply(.restart) == .ignored)
        #expect(session.revision == 0)
    }

    @Test("normal move animates and increments revision")
    func normalMove() throws {
        let session = try started(
            """
            #####
            # @ #
            # .$#
            #####
            """
        )
        let result = move(session, .left)
        guard case .emitted(let emission) = result else {
            Issue.record("expected emission")
            return
        }
        #expect(emission.render.delivery == .animate)
        #expect(emission.render.baseRevision == 1)
        #expect(emission.render.targetRevision == 2)
        #expect(emission.audio.delivery == .perform)
        #expect(emission.audio.targetRevision == 2)
        #expect(emission.audio.events == emission.render.events)
        #expect(session.revision == 2)
        #expect(session.undoCount == 1)
    }

    @Test("push with multiple events is still one revision")
    func pushOneRevision() throws {
        let session = try started(
            """
            #####
            #@$.#
            #####
            """
        )
        let result = move(session, .right)
        guard case .emitted(let emission) = result else {
            Issue.record("expected emission")
            return
        }
        #expect(emission.render.events.count > 1)
        #expect(emission.render.targetRevision == 2)
        #expect(session.revision == 2)
        #expect(emission.appTransition == .enterOutcomePresenting)
        #expect(session.phase == .outcomePresenting)
    }

    @Test("blocked move with event increments revision without undo")
    func blockedWithEvent() throws {
        let session = try started(
            """
            #####
            #@#.#
            # $ #
            #####
            """
        )
        let beforeUndo = session.undoCount
        let result = move(session, .right)
        guard case .emitted(let emission) = result else {
            Issue.record("expected emission")
            return
        }
        #expect(
            emission.render.events.contains { event in
                if case .movementBlocked = event { return true }
                return false
            })
        #expect(emission.render.targetRevision == 2)
        #expect(session.undoCount == beforeUndo)
    }

    @Test("push onto a guaranteed static dead square is prevented")
    func staticDeadlockPushPrevented() throws {
        let session = try started(
            """
            #######
            #     #
            # # $ #
            # @ . #
            #######
            """
        )
        for direction in [Direction.right, .up] {
            guard case .emitted = move(session, direction) else {
                Issue.record("setup move failed")
                return
            }
        }

        let result = move(session, .right)
        guard case .emitted(let emission) = result else {
            Issue.record("expected blocked deadlock feedback")
            return
        }

        #expect(session.preventedStaticDeadlockOnLastMove)
        #expect(session.journalCommandCount == 2)
        #expect(session.undoCount == 2)
        #expect(emission.render.snapshot.metrics.sokoban?.moveCount == 2)
        #expect(emission.render.snapshot.metrics.sokoban?.pushCount == 0)
        #expect(emission.render.snapshot.player.position == GridPosition(column: 3, row: 2))
        #expect(emission.render.snapshot.entities.first?.position == GridPosition(column: 4, row: 2))
        #expect(emission.render.events == [.movementBlocked(at: GridPosition(column: 3, row: 2))])
    }

    @Test("moves in outcomePresenting are rejected at the session boundary")
    func emptyTerminalMove() throws {
        let session = try makeSession("#@*#")
        _ = session.start()
        #expect(session.phase == .outcomePresenting)
        let revision = session.revision
        #expect(session.submitMove(.up) == .ignored)
        #expect(session.revision == revision)
    }

    @Test("undo redo restart hard-resync and clear redo after new move")
    func undoRedoRestart() throws {
        let session = try started(
            """
            ######
            # @  #
            # .$ #
            ######
            """
        )
        guard case .emitted = move(session, .right) else {
            Issue.record("move failed")
            return
        }
        guard case .emitted(let undoEmission) = session.apply(.undo) else {
            Issue.record("undo failed")
            return
        }
        #expect(undoEmission.render.delivery == .hardResync)
        #expect(undoEmission.audio.delivery == .synchronize)
        #expect(undoEmission.audio.events.isEmpty)
        #expect(session.redoCount == 1)

        guard case .emitted(let redoEmission) = session.apply(.redo) else {
            Issue.record("redo failed")
            return
        }
        #expect(redoEmission.render.delivery == .hardResync)

        guard case .emitted = session.apply(.undo) else {
            Issue.record("second undo failed")
            return
        }
        #expect(session.redoCount == 1)
        guard case .emitted = move(session, .left) else {
            Issue.record("move after undo failed")
            return
        }
        #expect(session.redoCount == 0)

        guard case .emitted(let restart) = session.apply(.restart) else {
            Issue.record("restart failed")
            return
        }
        #expect(restart.render.delivery == .hardResync)
        #expect(session.undoCount == 0)
        #expect(session.redoCount == 0)
    }

    @Test("undo from completed returns to playing")
    func undoFromCompleted() throws {
        let session = try started(
            """
            #####
            #@$.#
            #####
            """
        )
        guard case .emitted = move(session, .right) else {
            Issue.record("complete move failed")
            return
        }
        #expect(session.phase == .outcomePresenting)
        guard case .emitted(let emission) = session.apply(.undo) else {
            Issue.record("undo failed")
            return
        }
        #expect(emission.appTransition == .returnToPlaying)
        #expect(session.phase == .playing)
        #expect(emission.render.snapshot.status == .playing)
    }

    @Test("multiple empty undos leave revision unchanged")
    func emptyUndoIgnored() throws {
        let session = try started(
            """
            #####
            #@$.#
            #####
            """
        )
        let revision = session.revision
        #expect(session.apply(.undo) == .ignored)
        #expect(session.apply(.redo) == .ignored)
        #expect(session.revision == revision)
    }

    @Test("every emission pairs render and audio on the same target revision")
    func pairedUpdates() throws {
        let session = try started(
            """
            #####
            #@$.#
            #####
            """
        )
        guard case .emitted(let emission) = move(session, .right) else {
            Issue.record("expected emission")
            return
        }
        #expect(emission.render.targetRevision == emission.audio.targetRevision)
        #expect(emission.render.targetRevision == emission.render.baseRevision + 1)
    }

    @Test("engine fault returns app-only result without bumping revision")
    func faultWithoutSnapshot() throws {
        let session = try started(
            """
            #####
            #@$.#
            #####
            """
        )
        let revision = session.revision
        session.replaceStateForTesting(makeCorruptStateOnWall())

        let result = session.submitMove(.right)
        guard case .faulted(let message) = result else {
            Issue.record("expected faulted result")
            return
        }
        #expect(!message.isEmpty)
        #expect(session.phase == .faulted)
        #expect(session.revision == revision)
        #expect(session.submitMove(.left) == .ignored)
        #expect(session.apply(.restart) == .ignored)
    }

    private func makeCorruptStateOnWall() -> SokobanState {
        // Player on wall violates essentials; the next move throws EngineFault.
        let cells = [
            SokobanCell(terrain: .wall),
            SokobanCell(terrain: .floor),
            SokobanCell(terrain: .goal, occupant: .crate(EntityID(2))),
        ]
        let grid = Grid(width: 3, height: 1, cells: cells)
        return SokobanState(
            grid: grid,
            playerPosition: GridPosition(column: 0, row: 0),
            playerID: EntityID(1),
            status: .playing,
            moveCount: 0,
            pushCount: 0
        )
    }
}
