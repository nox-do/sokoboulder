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

    /// Enqueue one move and process the queue; returns the single result.
    private func move(_ session: GameSession, _ direction: Direction) -> SessionApplyResult {
        #expect(session.enqueueMove(direction))
        let results = session.processPendingMoves()
        #expect(results.count == 1)
        return results[0]
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
        #expect(session.enqueueMove(.right) == false)
        #expect(session.apply(.undo) == .ignored)
        #expect(session.apply(.redo) == .ignored)
        #expect(session.apply(.restart) == .ignored)
        #expect(session.processPendingMoves().isEmpty)
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
        #expect(emission.render.events.contains { event in
            if case .movementBlocked = event { return true }
            return false
        })
        #expect(emission.render.targetRevision == 2)
        #expect(session.undoCount == beforeUndo)
    }

    @Test("empty terminal move emits nothing")
    func emptyTerminalMove() throws {
        let session = try makeSession("#@*#")
        _ = session.start()
        let revision = session.revision
        let result = move(session, .up)
        #expect(result == .ignored)
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

    @Test("undo clears pending move queue")
    func undoClearsPendingQueue() throws {
        let session = try started(
            """
            #######
            # @   #
            # .$  #
            #######
            """
        )
        #expect(session.enqueueMove(.right))
        #expect(session.enqueueMove(.right))
        #expect(session.pendingMoveCount == 2)
        _ = session.apply(.undo)
        #expect(session.pendingMoveCount == 0)
    }

    @Test("move queue accepts two and drops the third")
    func moveQueueLimit() throws {
        let session = try started(
            """
            #######
            # @   #
            # .$  #
            #######
            """
        )
        #expect(session.enqueueMove(.right))
        #expect(session.enqueueMove(.right))
        #expect(session.enqueueMove(.right) == false)
        #expect(session.pendingMoveCount == 2)
        let results = session.processPendingMoves()
        #expect(results.count == 2)
        #expect(session.pendingMoveCount == 0)
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

        #expect(session.enqueueMove(.right))
        let results = session.processPendingMoves()
        #expect(results.count == 1)
        guard case .faulted(let message) = results[0] else {
            Issue.record("expected faulted result")
            return
        }
        #expect(!message.isEmpty)
        #expect(session.phase == .faulted)
        #expect(session.revision == revision)
        #expect(session.enqueueMove(.left) == false)
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