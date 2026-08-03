import Foundation
import Testing

@testable import GameCore
@testable import MacGameApp

@Suite("Sokoban move hold repeater")
@MainActor
struct SokobanMoveHoldRepeaterTests {
    @Test("key-down fires immediately and repeats after delays")
    func firesImmediateThenRepeats() async throws {
        let repeater = SokobanMoveHoldRepeater()
        repeater.initialDelay = 0.02
        repeater.repeatInterval = 0.02
        var fired: [Direction] = []
        repeater.onFire = { fired.append($0) }

        repeater.noteKeyDown(keyCode: KeyCode.rightArrow, direction: .right)
        #expect(fired == [.right])

        // Sleep off the main actor so DispatchQueue.main timers can fire.
        try await Self.sleepOffMain(nanoseconds: 120_000_000)
        // Immediate fire + at least one scheduled repeat (load may delay further ticks).
        #expect(fired.count >= 2)
        #expect(Set(fired) == [.right])

        repeater.noteKeyUp(keyCode: KeyCode.rightArrow)
        let countAfterUp = fired.count
        try await Self.sleepOffMain(nanoseconds: 50_000_000)
        #expect(fired.count == countAfterUp)
    }

    @Test("last pressed direction wins while multiple keys are held")
    func lastPressedWins() async throws {
        let repeater = SokobanMoveHoldRepeater()
        repeater.initialDelay = 0.02
        repeater.repeatInterval = 0.02
        var fired: [Direction] = []
        repeater.onFire = { fired.append($0) }

        repeater.noteKeyDown(keyCode: KeyCode.rightArrow, direction: .right)
        repeater.noteKeyDown(keyCode: KeyCode.upArrow, direction: .up)
        #expect(fired == [.right, .up])
        #expect(repeater.activeDirection == .up)

        try await Self.sleepOffMain(nanoseconds: 80_000_000)
        #expect(fired.suffix(2).allSatisfy { $0 == .up })

        repeater.noteKeyUp(keyCode: KeyCode.upArrow)
        #expect(repeater.activeDirection == .right)
        try await Self.sleepOffMain(nanoseconds: 80_000_000)
        #expect(fired.last == .right)

        repeater.clear()
    }

    @Test("clear stops repeats")
    func clearStops() async throws {
        let repeater = SokobanMoveHoldRepeater()
        repeater.initialDelay = 0.02
        repeater.repeatInterval = 0.02
        var fired = 0
        repeater.onFire = { _ in fired += 1 }

        repeater.noteKeyDown(keyCode: KeyCode.leftArrow, direction: .left)
        repeater.clear()
        let afterClear = fired
        try await Self.sleepOffMain(nanoseconds: 50_000_000)
        #expect(fired == afterClear)
        #expect(!repeater.isHolding)
    }

    /// Yields without occupying the main actor, then hops back so main timers flush.
    private static func sleepOffMain(nanoseconds: UInt64) async throws {
        try await Task.detached {
            try await Task.sleep(nanoseconds: nanoseconds)
        }.value
        await Task.yield()
    }
}

@Suite("Sokoban hold-to-move play controller")
@MainActor
struct SokobanHoldMoveControllerTests {
    private func makeController() -> SokobanPlayController {
        let persistence = try! SokobanRunPersistence.ephemeral()
        let catalog = try! BundleContentLoader.loadSokobanCatalog(
            from: Bundle(for: SokobanPlayController.self)
        )
        let progress = try! ProgressPersistence.ephemeral(firstLevelID: catalog.first.id)
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: persistence,
            progressPersistence: progress,
            catalog: catalog,
            settingsStore: AppSettingsStore.ephemeral()
        )
        if controller.presentationPhase == .gameSelection {
            controller.selectSokobanFromGameSelection()
        }
        controller.dismissLevelIntro()
        return controller
    }

    @Test("holding a direction advances more than one step")
    func holdingAdvancesMultipleSteps() async throws {
        let controller = makeController()
        // Reach into the private repeater via a short public test seam:
        // use the default delays would be slow; instead drive key events and
        // rely on the repeater defaults being overridden in a DEBUG helper.
        controller.configureMoveHoldForTesting(initialDelay: 0.02, repeatInterval: 0.02)

        let before = try #require(controller.session).revision
        #expect(controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.rightArrow)))
        try await Task.detached { try await Task.sleep(nanoseconds: 70_000_000) }.value
        #expect(controller.handleKeyEvent(TestKeyEvent.keyUp(KeyCode.rightArrow)))
        let after = try #require(controller.session).revision
        #expect(after >= before + 2)
    }

    @Test("pause clears held movement")
    func pauseClearsHold() async throws {
        let controller = makeController()
        controller.configureMoveHoldForTesting(initialDelay: 0.02, repeatInterval: 0.02)
        #expect(controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.rightArrow)))
        controller.togglePause()
        let revision = try #require(controller.session).revision
        try await Task.detached { try await Task.sleep(nanoseconds: 60_000_000) }.value
        #expect(controller.session?.revision == revision)
    }
}
