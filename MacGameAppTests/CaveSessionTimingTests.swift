import Foundation
import GameCore
import Testing

@testable import MacGameApp

@Suite("CaveSession timing (Ready → Tick 1)")
@MainActor
struct CaveSessionTimingTests {
    @Test("ready emits no ticks until the first intent")
    func readyHasNoTicksWithoutInput() throws {
        let session = try makeSession()
        let boot = session.start()
        #expect(session.phase == .ready)
        #expect(session.simulationTick == 0)
        #expect(boot.render.delivery == .hardResync)

        #expect(try session.advance(to: 1.0) == nil)
        #expect(session.phase == .ready)
        #expect(session.simulationTick == 0)
    }

    @Test("first move leaves ready and becomes tick 1")
    func firstMoveIsTickOne() throws {
        let session = try makeSession()
        _ = session.start()
        session.noteDirectionDown(.right)
        let emission = try session.advance(to: 0.5)
        #expect(emission != nil)
        #expect(session.phase == .playing || session.phase == .outcomePresenting)
        #expect(session.simulationTick == 1)
    }

    @Test("catch-up runs multiple ticks then emits once")
    func catchUpAggregates() throws {
        let session = try makeSession()
        _ = session.start()
        session.noteWait()
        _ = try session.advance(to: 0)
        #expect(session.simulationTick == 1)

        let emission = try session.advance(to: CaveRules.fixedStepSeconds * 3.5)
        #expect(emission != nil)
        #expect(session.simulationTick >= 3)
    }

    @Test("Releasing one of two keys for the same direction keeps cave movement held")
    func movementAliasesRemainIndependent() throws {
        let level = try CaveLevelBuilder.level(
            fromASCII: "#########\n#P     E#\n#########", requiredDiamonds: 0
        )
        let session = try CaveSession(level: level)
        let router = GameplayInputRouter()
        session.start()

        _ = router.route(TestKeyEvent.keyDown(KeyCode.rightArrow))
        session.noteDirectionDown(.right)
        _ = try session.advance(to: 0, heldDirection: router.heldDirection)
        _ = router.route(TestKeyEvent.keyDown(KeyCode.d))
        session.noteDirectionDown(.right)
        _ = router.route(TestKeyEvent.keyUp(KeyCode.rightArrow))
        _ = try session.advance(to: 0.11, heldDirection: router.heldDirection)
        _ = try session.advance(to: 0.22, heldDirection: router.heldDirection)
        #expect(session.snapshot.player.position.column == 4)

        _ = router.route(TestKeyEvent.keyUp(KeyCode.d))
        _ = try session.advance(to: 0.33, heldDirection: router.heldDirection)
        #expect(session.snapshot.player.position.column == 4)
    }

    @Test("terminal death performs audio cues including playerDied")
    func terminalDeathPerformsPlayerDiedCue() throws {
        // Falling boulder one cell above the player; wait lets gravity kill.
        let ascii = """
            #####
            # O #
            #   #
            # P #
            #  E#
            #####
            """
        let level = try CaveLevelBuilder.level(
            fromASCII: ascii,
            requiredDiamonds: 0,
            timeLimitTicks: 100
        )
        let session = try CaveSession(level: level, levelID: "cave.test.crush")
        _ = session.start()
        session.noteWait()

        var sawDeath = false
        var now: TimeInterval = 0
        for _ in 0..<20 {
            if let emission = try session.advance(to: now) {
                if emission.audio.delivery == .perform,
                    emission.audio.events.contains(where: {
                        if case .playerDied = $0 { return true }
                        return false
                    })
                {
                    sawDeath = true
                    #expect(session.phase == .outcomePresenting)
                    #expect(emission.appTransition == .enterOutcomePresenting)
                    break
                }
            }
            now += CaveRules.fixedStepSeconds
        }
        #expect(sawDeath)
    }

    @Test("latest explicit input wins between ticks", arguments: [false, true])
    func latestInputWins(waitLast: Bool) throws {
        let level = try CaveLevelBuilder.level(
            fromASCII: "#######\n#P   E#\n#######", requiredDiamonds: 0
        )
        let session = try CaveSession(level: level)
        session.start()
        session.noteWait()
        _ = try session.advance(to: 0)

        if waitLast {
            session.noteDirectionDown(.right)
            session.noteWait()
        } else {
            session.noteWait()
            session.noteDirectionDown(.right)
        }
        _ = try session.advance(to: 0.11)
        #expect(session.snapshot.player.position.column == (waitLast ? 1 : 2))
        // A released tap is consumed once, never replayed in the following tick.
        _ = try session.advance(to: 0.22)
        #expect(session.snapshot.player.position.column == (waitLast ? 1 : 2))
    }

    @Test("pause clears pending input and resumes with a fresh clock")
    func pauseClearsPendingInput() throws {
        let level = try CaveLevelBuilder.level(
            fromASCII: "#######\n#P   E#\n#######", requiredDiamonds: 0
        )
        let session = try CaveSession(level: level)
        session.start()
        session.noteWait()
        _ = try session.advance(to: 0)
        session.noteDirectionDown(.right)
        session.pause()
        session.resume()
        #expect(try session.advance(to: 10) == nil)
        _ = try session.advance(to: 10.11)
        #expect(session.simulationTick == 2)
        #expect(session.snapshot.player.position.column == 1)
    }

    private func makeSession() throws -> CaveSession {
        let level = try CaveDemoLevel.makeLevel()
        return try CaveSession(level: level, levelID: CaveDemoLevel.id)
    }
}
