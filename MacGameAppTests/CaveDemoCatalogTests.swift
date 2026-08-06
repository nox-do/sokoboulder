import Foundation
import Testing
@testable import MacGameApp
import GameCore

@Suite("Cave content catalog")
struct CaveDemoCatalogTests {
    @Test("bundled cave catalog loads demo campaign")
    func catalogLoads() throws {
        let catalog = try BundleContentLoader.loadCaveCatalog(
            from: Foundation.Bundle(for: SokobanPlayController.self)
        )
        #expect(catalog.levels.count == 35)
        #expect(catalog.first.id == "cave.demo.001")
        #expect(catalog.descriptor(after: "cave.demo.001")?.id == "cave.demo.002")
        #expect(catalog.descriptor(after: "cave.demo.003")?.id == "cave.demo.004")
        #expect(catalog.descriptor(after: "cave.demo.035") == nil)
        #expect(catalog.title(for: catalog.first) == "Der erste Diamant")
        #expect(catalog.title(for: catalog.levels[3]) == "Höhle 4")
        #expect(catalog.title(for: catalog.levels[33]) == "Insekten")
        #expect(catalog.title(for: catalog.levels[34]) == "Magische Wand")
        #expect(!catalog.tutorialHint(for: catalog.first).isEmpty)
        #expect(catalog.tutorialHint(for: catalog.levels[3]).isEmpty)
        #expect(!catalog.tutorialHint(for: catalog.levels[33]).isEmpty)
        #expect(!catalog.tutorialHint(for: catalog.levels[34]).isEmpty)
        #expect(catalog.tutorialLevelIDs == [
            "cave.demo.001",
            "cave.demo.002",
            "cave.demo.003",
        ])
    }

    @Test("compatibility helper loads first demo")
    func firstAlias() throws {
        #expect(CaveDemoLevel.id == "cave.demo.001")
        let level = try CaveDemoLevel.makeLevel()
        #expect(level.requiredDiamonds == 1)
    }

    @Test("cave intro shows goals then stays ready until first move")
    @MainActor
    func caveIntroThenReady() throws {
        let bundle = Foundation.Bundle(for: SokobanPlayController.self)
        let catalog = try BundleContentLoader.loadSokobanCatalog(from: bundle)
        let caveCatalog = try BundleContentLoader.loadCaveCatalog(from: bundle)
        let controller = SokobanPlayController(
            audioDirector: AudioDirector(backend: NoOpAudioPlaybackBackend()),
            runPersistence: try SokobanRunPersistence.ephemeral(),
            progressPersistence: try ProgressPersistence.ephemeral(
                firstLevelID: catalog.first.id,
                caveTutorialLevelIDs: caveCatalog.tutorialLevelIDs
            ),
            catalog: catalog,
            caveCatalog: caveCatalog,
            settingsStore: AppSettingsStore.ephemeral()
        )
        #expect(controller.presentationPhase == GamePresentationPhase.gameSelection)
        controller.selectCaveFromGameSelection()

        #expect(controller.presentationPhase == GamePresentationPhase.levelIntro)
        #expect(controller.isCaveMode)
        #expect(controller.caveSession?.phase == SessionPhase.ready)

        let intro = controller.levelIntroPresentation
        #expect(intro.title == "Der erste Diamant")
        #expect(intro.body.contains("Diamanten"))
        #expect(intro.body.contains("Zeit"))

        controller.dismissLevelIntro()
        #expect(controller.presentationPhase == GamePresentationPhase.playing)
        #expect(controller.caveSession?.phase == SessionPhase.ready)
        #expect(controller.caveSession?.simulationTick == 0)

        #expect(controller.handleKeyEvent(TestKeyEvent.keyDown(KeyCode.rightArrow)))
        #expect(controller.caveSession?.simulationTick == 1)
    }
}
