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

        #expect(session.advance(to: 1.0) == nil)
        #expect(session.phase == .ready)
        #expect(session.simulationTick == 0)
    }

    @Test("first move leaves ready and becomes tick 1")
    func firstMoveIsTickOne() throws {
        let session = try makeSession()
        _ = session.start()
        session.noteDirectionDown(.right)
        let emission = session.advance(to: 0.5)
        #expect(emission != nil)
        #expect(session.phase == .playing || session.phase == .outcomePresenting)
        #expect(session.simulationTick == 1)
    }

    @Test("catch-up runs multiple ticks then emits once")
    func catchUpAggregates() throws {
        let session = try makeSession()
        _ = session.start()
        session.noteWait()
        _ = session.advance(to: 0)
        #expect(session.simulationTick == 1)

        let emission = session.advance(to: CaveRules.fixedStepSeconds * 3.5)
        #expect(emission != nil)
        #expect(session.simulationTick >= 3)
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
            if let emission = session.advance(to: now) {
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

    private func makeSession() throws -> CaveSession {
        let level = try CaveDemoLevel.makeLevel()
        return try CaveSession(level: level, levelID: CaveDemoLevel.id)
    }
}
