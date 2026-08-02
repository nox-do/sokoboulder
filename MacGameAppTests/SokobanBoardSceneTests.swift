import CoreGraphics
import Testing

@testable import GameCore
@testable import MacGameApp

@Suite("SokobanBoardScene revision contract")
@MainActor
struct SokobanBoardSceneTests {
    private func startedSession(_ ascii: String) throws -> GameSession {
        let level = try SokobanLevelValidator.level(fromASCII: ascii)
        let session = try GameSession(level: level, levelID: "render")
        _ = session.start()
        return session
    }

    private func makeScene(size: CGSize = CGSize(width: 320, height: 240)) -> SokobanBoardScene {
        let scene = SokobanBoardScene(size: size)
        scene.holdAnimationsForTesting = false
        return scene
    }

    @Test("initial hard-resync builds the snapshot")
    func initialHardResync() throws {
        let session = try startedSession(
            """
            #####
            #@$.#
            #####
            """
        )
        let scene = makeScene()
        let emission = session.bootstrapEmission!
        scene.apply(emission.render)

        #expect(scene.appliedRevision == 1)
        #expect(scene.terrainNodeCountForTesting == 15)
        #expect(scene.entityNodeCountForTesting == 2)  // player + crate
        #expect(scene.currentSnapshot?.player.position == GridPosition(column: 1, row: 1))
    }

    @Test("gapless animate updates revision")
    func gaplessAnimate() throws {
        let session = try startedSession(
            """
            #####
            # @ #
            # .$#
            #####
            """
        )
        let scene = makeScene()
        scene.apply(session.bootstrapEmission!.render)

        let results = session.submitMove(.left)
        guard case .emitted(let emission) = results[0] else {
            Issue.record("expected move emission")
            return
        }
        scene.apply(emission.render)
        #expect(scene.appliedRevision == 2)
        #expect(scene.currentSnapshot?.player.position.column == 1)
    }

    @Test("blocked movement is forwarded as visible renderer feedback")
    func blockedMovementFeedback() throws {
        let session = try startedSession(
            """
            #####
            #@$.#
            #####
            """
        )
        let scene = makeScene()
        scene.holdAnimationsForTesting = true
        scene.apply(session.bootstrapEmission!.render)

        guard case .emitted(let emission) = session.submitMove(.left)[0] else {
            Issue.record("expected blocked event emission")
            return
        }
        scene.apply(emission.render)

        #expect(
            scene.lastEventsForTesting == [
                .movementBlocked(at: GridPosition(column: 0, row: 1))
            ])
        #expect(scene.pendingAnimationCount == 1)
    }

    @Test("crate on goal has a non-color state marker")
    func crateGoalMarker() throws {
        let session = try startedSession(
            """
            #####
            #@$.#
            #####
            """
        )
        let scene = makeScene()
        scene.holdAnimationsForTesting = true
        scene.apply(session.bootstrapEmission!.render)

        guard case .emitted(let emission) = session.submitMove(.right)[0] else {
            Issue.record("expected terminal push")
            return
        }
        scene.apply(emission.render)
        scene.settleAnimationsForTesting()

        #expect(scene.crateGoalMarkerCountForTesting == 1)
    }

    @Test("artificial revision gap triggers hard-resync")
    func revisionGapHardResync() throws {
        let session = try startedSession(
            """
            #######
            # @   #
            # .$  #
            #######
            """
        )
        let scene = makeScene()
        scene.apply(session.bootstrapEmission!.render)

        let first = session.submitMove(.right)
        let second = session.submitMove(.right)
        guard case .emitted(let a) = first[0],
            case .emitted(let b) = second[0]
        else {
            Issue.record("expected emissions")
            return
        }

        // Skip intermediate update → gap from revision 1 to base 2.
        scene.apply(b.render)
        #expect(scene.appliedRevision == b.render.targetRevision)
        #expect(scene.pendingAnimationCount == 0)
        #expect(scene.currentSnapshot?.player.position == b.render.snapshot.player.position)
        _ = a  // silence unused; documents the skipped intermediate
    }

    @Test("hard-resync clears running animations")
    func hardResyncClearsAnimations() throws {
        let session = try startedSession(
            """
            #######
            # @   #
            # .$  #
            #######
            """
        )
        let scene = makeScene()
        scene.holdAnimationsForTesting = true
        scene.apply(session.bootstrapEmission!.render)

        guard case .emitted(let moveEmission) = session.submitMove(.right)[0] else {
            Issue.record("expected move")
            return
        }
        scene.apply(moveEmission.render)
        #expect(scene.pendingAnimationCount == 1)

        guard case .emitted(let undoEmission) = session.apply(.undo) else {
            Issue.record("expected undo")
            return
        }
        #expect(undoEmission.render.delivery == .hardResync)
        scene.apply(undoEmission.render)
        #expect(scene.pendingAnimationCount == 0)
        #expect(scene.appliedRevision == undoEmission.render.targetRevision)
    }

    @Test("ordered updates queue FIFO without aborting prior steps")
    func orderedUpdatesReachLatest() throws {
        let session = try startedSession(
            """
            #######
            # @   #
            # .$  #
            #######
            """
        )
        let scene = makeScene()
        scene.holdAnimationsForTesting = true
        scene.apply(session.bootstrapEmission!.render)

        #expect(session.enqueueMove(.right))
        #expect(session.enqueueMove(.right))
        let results = session.processPendingMoves()
        let emissions = results.compactMap { result -> SessionEmission? in
            if case .emitted(let emission) = result { return emission }
            return nil
        }
        #expect(emissions.count == 2)
        scene.apply(emissions: emissions)

        // First step in-flight, second queued — no premature hard-resync.
        #expect(scene.isAnimatingForTesting)
        #expect(scene.queuedAnimationCountForTesting == 1)
        #expect(scene.pendingAnimationCount == 2)
        #expect(scene.appliedRevision == emissions.last!.render.targetRevision)

        scene.settleAnimationsForTesting()
        #expect(scene.pendingAnimationCount == 0)
        #expect(
            scene.currentSnapshot?.player.position
                == emissions.last!.render.snapshot.player.position
        )
    }

    @Test("resize aborts presentation without stranding the animation counter")
    func resizeAbortsPendingAnimations() throws {
        let session = try startedSession(
            """
            #######
            # @   #
            # .$  #
            #######
            """
        )
        let scene = makeScene()
        scene.holdAnimationsForTesting = true
        scene.apply(session.bootstrapEmission!.render)
        guard case .emitted(let emission) = session.submitMove(.right)[0] else {
            Issue.record("expected move")
            return
        }
        scene.apply(emission.render)
        #expect(scene.pendingAnimationCount == 1)

        scene.resize(to: CGSize(width: 400, height: 300))
        #expect(scene.pendingAnimationCount == 0)
        #expect(scene.appliedRevision == emission.render.targetRevision)
        #expect(session.revision == emission.render.targetRevision)
    }

    @Test("overflowing animation buffer resyncs to newest snapshot")
    func animationBudgetResync() throws {
        let session = try startedSession(
            """
            #########
            # @     #
            # .$    #
            #########
            """
        )
        let scene = makeScene()
        scene.holdAnimationsForTesting = true
        scene.apply(session.bootstrapEmission!.render)

        var lastEmission: SessionEmission?
        for _ in 0..<SokobanBoardScene.animationBudget {
            let results = session.submitMove(.right)
            guard case .emitted(let emission) = results[0] else {
                Issue.record("expected emission")
                return
            }
            scene.apply(emission.render)
            lastEmission = emission
        }
        #expect(scene.pendingAnimationCount == SokobanBoardScene.animationBudget)

        let overflow = session.submitMove(.right)
        guard case .emitted(let overflowEmission) = overflow[0] else {
            Issue.record("expected overflow emission")
            return
        }
        scene.apply(overflowEmission.render)
        #expect(scene.pendingAnimationCount == 0)
        #expect(scene.appliedRevision == overflowEmission.render.targetRevision)
        #expect(
            scene.currentSnapshot?.player.position
                == overflowEmission.render.snapshot.player.position
        )
        #expect(lastEmission != nil)
    }

    @Test("whenSettled fires after hard-resync and after forced settle")
    func whenSettledContract() throws {
        let session = try startedSession(
            """
            #####
            #@$.#
            #####
            """
        )
        let scene = makeScene()
        scene.holdAnimationsForTesting = true
        scene.apply(session.bootstrapEmission!.render)

        var settled = false
        guard case .emitted(let emission) = session.submitMove(.right)[0] else {
            Issue.record("expected move")
            return
        }
        scene.apply(emission.render)
        scene.whenSettled(revision: emission.render.targetRevision) {
            settled = true
        }
        #expect(settled == false)
        scene.settleAnimationsForTesting()
        #expect(settled)
        #expect(scene.settledRevision == emission.render.targetRevision)
    }

    @Test("prepareForNewSession clears revision stream and waiters")
    func prepareForNewSessionResets() throws {
        let session = try startedSession(
            """
            #####
            #@$.#
            #####
            """
        )
        let scene = makeScene()
        scene.holdAnimationsForTesting = true
        scene.apply(session.bootstrapEmission!.render)
        guard case .emitted(let emission) = session.submitMove(.right)[0] else {
            Issue.record("expected move")
            return
        }
        scene.apply(emission.render)

        var fired = false
        scene.whenSettled(revision: 99) { fired = true }
        #expect(scene.appliedRevision >= 2)
        #expect(scene.pendingAnimationCount > 0)

        scene.prepareForNewSession()
        #expect(scene.appliedRevision == 0)
        #expect(scene.settledRevision == 0)
        #expect(scene.pendingAnimationCount == 0)
        #expect(scene.currentSnapshot == nil)
        #expect(fired == false)

        let level = try SokobanLevelValidator.level(
            fromASCII:
                """
                #####
                #@$.#
                #####
                """
        )
        let fresh = try GameSession(level: level, levelID: "fresh")
        let bootstrap = fresh.start()
        scene.apply(bootstrap.render)
        #expect(scene.appliedRevision == 1)
        #expect(scene.settledRevision == 1)
    }

    @Test("resize changes geometry only, not session state")
    func resizeDoesNotTouchSession() throws {
        let session = try startedSession(
            """
            #####
            #@$.#
            #####
            """
        )
        let scene = makeScene(size: CGSize(width: 200, height: 200))
        scene.apply(session.bootstrapEmission!.render)
        let revision = session.revision
        let phase = session.phase
        let playerBefore = scene.currentSnapshot?.player.position

        scene.resize(to: CGSize(width: 400, height: 300))
        #expect(session.revision == revision)
        #expect(session.phase == phase)
        #expect(scene.currentSnapshot?.player.position == playerBefore)
        #expect(scene.geometryForTesting.availableSize == CGSize(width: 400, height: 300))
        #expect(scene.geometryForTesting.tileSize > 0)
    }
}
