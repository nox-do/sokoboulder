import Foundation
import Testing
@testable import MacGameApp
import GameCore

@Suite("Cave demo catalog")
struct CaveDemoCatalogTests {
    @Test("three demos parse and keep diamond requirements")
    func catalogParses() throws {
        #expect(CaveDemoCatalog.levels.count == 3)
        for descriptor in CaveDemoCatalog.levels {
            let level = try descriptor.makeLevel()
            #expect(level.requiredDiamonds == descriptor.requiredDiamonds)
            #expect(level.width >= 8)
            #expect(level.height >= 6)
            #expect(CaveDemoCatalog.descriptor(id: descriptor.id)?.id == descriptor.id)
        }
        #expect(CaveDemoCatalog.descriptor(after: "cave.demo.001")?.id == "cave.demo.002")
        #expect(CaveDemoCatalog.descriptor(after: "cave.demo.002")?.id == "cave.demo.003")
        #expect(CaveDemoCatalog.descriptor(after: "cave.demo.003") == nil)
    }

    @Test("compatibility alias still loads the first demo")
    func firstAlias() throws {
        #expect(CaveDemoLevel.id == "cave.demo.001")
        let level = try CaveDemoLevel.makeLevel()
        #expect(level.requiredDiamonds == 1)
    }

    @Test("cave intro shows goals then stays ready until first move")
    @MainActor
    func caveIntroThenReady() throws {
        let catalog = try BundleContentLoader.loadSokobanCatalog(
            from: Foundation.Bundle(for: SokobanPlayController.self)
        )
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: try SokobanRunPersistence.ephemeral(),
            progressPersistence: try ProgressPersistence.ephemeral(firstLevelID: catalog.first.id),
            catalog: catalog,
            settingsStore: AppSettingsStore.ephemeral()
        )
        #expect(controller.presentationPhase == GamePresentationPhase.gameSelection)
        controller.selectCaveFromGameSelection()

        #expect(controller.presentationPhase == GamePresentationPhase.levelIntro)
        #expect(controller.isCaveMode)
        #expect(controller.caveSession?.phase == SessionPhase.ready)
        #expect(controller.router.mode == .levelIntro)

        let intro = controller.levelIntroPresentation
        #expect(intro.title == "Der erste Diamant")
        #expect(intro.body.contains("Diamanten"))
        #expect(intro.body.contains("Zeit"))
        #expect(intro.continueTitle == AppStrings.text(.uiCaveIntroStart))

        controller.dismissLevelIntro()
        #expect(controller.presentationPhase == GamePresentationPhase.playing)
        #expect(controller.caveSession?.phase == SessionPhase.ready)
        #expect(controller.caveSession?.simulationTick == 0)

        #expect(controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.rightArrow)))
        #expect(controller.caveSession?.simulationTick == 1)
    }

    @Test("cave intro time formatting")
    func caveTimeFormat() {
        #expect(PresentationFactory.formatCaveTimeLimit(seconds: 45) == "45 s")
        #expect(PresentationFactory.formatCaveTimeLimit(seconds: 90) == "1:30")
    }
}
