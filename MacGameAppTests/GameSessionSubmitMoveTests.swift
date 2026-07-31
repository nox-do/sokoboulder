import Testing
@testable import GameCore
@testable import MacGameApp

@Suite("GameSession submitMove / pause / outcome drain")
@MainActor
struct GameSessionSubmitMoveTests {
    private func started(_ ascii: String) throws -> GameSession {
        let level = try SokobanLevelValidator.level(fromASCII: ascii)
        let session = try GameSession(level: level, levelID: "test.level")
        _ = session.start()
        return session
    }

    @Test("submitMove processes one move immediately")
    func submitMoveImmediate() throws {
        let session = try started(
            """
            #####
            # @ #
            # .$#
            #####
            """
        )
        let results = session.submitMove(.left)
        #expect(results.count == 1)
        guard case .emitted(let emission) = results[0] else {
            Issue.record("expected emission")
            return
        }
        #expect(emission.render.targetRevision == 2)
        #expect(session.revision == 2)
        #expect(session.pendingMoveCount == 0)
    }

    @Test("two buffered moves emit ordered gapless revisions with intermediate snapshots")
    func twoBufferedMovesOrdered() throws {
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
        let results = session.processPendingMoves()
        #expect(results.count == 2)

        guard case .emitted(let first) = results[0],
              case .emitted(let second) = results[1]
        else {
            Issue.record("expected two emissions")
            return
        }

        #expect(first.render.baseRevision == 1)
        #expect(first.render.targetRevision == 2)
        #expect(second.render.baseRevision == 2)
        #expect(second.render.targetRevision == 3)
        #expect(first.render.snapshot.player.position.column == 3)
        #expect(second.render.snapshot.player.position.column == 4)
        #expect(first.render.snapshot != second.render.snapshot)
    }

    @Test("render and audio stay paired per emission")
    func pairedPerEmission() throws {
        let session = try started(
            """
            #####
            #@$.#
            #####
            """
        )
        let results = session.submitMove(.right)
        guard case .emitted(let emission) = results[0] else {
            Issue.record("expected emission")
            return
        }
        #expect(emission.render.targetRevision == emission.audio.targetRevision)
        #expect(emission.audio.events == emission.render.events)
    }

    @Test("ignored results are not treated as emissions")
    func ignoredNotEmission() throws {
        let session = try started(
            """
            #####
            #@$.#
            #####
            """
        )
        let revision = session.revision
        #expect(session.apply(.undo) == .ignored)
        #expect(session.revision == revision)
        #expect(session.bootstrapEmission != nil)
    }

    @Test("terminal first move ends drain and discards second")
    func terminalEndsDrain() throws {
        let session = try started(
            """
            #####
            #@$.#
            #####
            """
        )
        #expect(session.enqueueMove(.right))
        #expect(session.enqueueMove(.left))
        #expect(session.pendingMoveCount == 2)

        let results = session.processPendingMoves()
        #expect(results.count == 1)
        guard case .emitted(let emission) = results[0] else {
            Issue.record("expected one emission")
            return
        }
        #expect(emission.appTransition == .enterOutcomePresenting)
        #expect(session.phase == .outcomePresenting)
        #expect(session.pendingMoveCount == 0)
        #expect(session.revision == 2)
    }

    @Test("moves rejected in outcomePresenting")
    func movesRejectedInOutcome() throws {
        let session = try started(
            """
            #####
            #@$.#
            #####
            """
        )
        _ = session.submitMove(.right)
        #expect(session.phase == .outcomePresenting)
        #expect(session.canAcceptMove == false)
        #expect(session.submitMove(.left).isEmpty)
        #expect(session.enqueueMove(.up) == false)
    }

    @Test("undo redo restart remain allowed in outcomePresenting")
    func commandsAllowedInOutcome() throws {
        let session = try started(
            """
            #####
            #@$.#
            #####
            """
        )
        _ = session.submitMove(.right)
        #expect(session.phase == .outcomePresenting)
        #expect(session.canAcceptSessionCommand)

        guard case .emitted = session.apply(.undo) else {
            Issue.record("undo should work")
            return
        }
        #expect(session.phase == .playing)

        _ = session.submitMove(.right)
        #expect(session.phase == .outcomePresenting)
        guard case .emitted = session.apply(.restart) else {
            Issue.record("restart should work")
            return
        }
        #expect(session.phase == .playing)
    }

    @Test("pause clears queue and rejects moves; resume restores")
    func pauseResume() throws {
        let session = try started(
            """
            #######
            # @   #
            # .$  #
            #######
            """
        )
        #expect(session.enqueueMove(.right))
        #expect(session.pendingMoveCount == 1)
        session.pause()
        #expect(session.phase == .paused)
        #expect(session.pendingMoveCount == 0)
        #expect(session.canAcceptMove == false)
        #expect(session.submitMove(.right).isEmpty)
        #expect(session.canAcceptSessionCommand == false)
        #expect(session.apply(.undo) == .ignored)

        session.resume()
        #expect(session.phase == .playing)
        #expect(session.canAcceptMove)
        let results = session.submitMove(.right)
        #expect(results.count == 1)
    }

    @Test("focus-loss interruption path clears the queue")
    func focusLossClearsQueue() throws {
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
        // Focus loss uses the same interruption mechanism as pause.
        session.pause()
        #expect(session.pendingMoveCount == 0)
        #expect(session.phase == .paused)
    }

    @Test("fault ends a batch without a new revision")
    func faultEndsBatch() throws {
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
        #expect(session.enqueueMove(.left))
        let results = session.processPendingMoves()
        #expect(results.count == 1)
        guard case .faulted = results[0] else {
            Issue.record("expected fault")
            return
        }
        #expect(session.revision == revision)
        #expect(session.pendingMoveCount == 0)
        #expect(session.phase == .faulted)
    }

    private func makeCorruptStateOnWall() -> SokobanState {
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
