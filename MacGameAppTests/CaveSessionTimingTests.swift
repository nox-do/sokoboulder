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

    private func makeSession() throws -> CaveSession {
        let level = try CaveDemoLevel.makeLevel()
        return try CaveSession(level: level, levelID: CaveDemoLevel.id)
    }
}
