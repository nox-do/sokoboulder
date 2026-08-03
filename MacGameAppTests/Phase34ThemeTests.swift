import Foundation
import GameCore
import Testing

@testable import MacGameApp

@Suite("Phase 3.4 theme contract")
struct Phase34ThemeTests {
    @Test("theme color parses RGB and RGBA hex")
    func colorParsing() throws {
        let rgb = try ThemeColor.parse("#F2BF33")
        #expect(abs(rgb.red - 242.0 / 255.0) < 0.001)
        #expect(abs(rgb.green - 191.0 / 255.0) < 0.001)
        #expect(abs(rgb.blue - 51.0 / 255.0) < 0.001)
        #expect(rgb.alpha == 1)

        let rgba = try ThemeColor.parse("#00000073")
        #expect(rgba.red == 0)
        #expect(abs(rgba.alpha - 115.0 / 255.0) < 0.001)

        #expect(throws: ThemeDecodeError.invalidColor("zz")) {
            _ = try ThemeColor.parse("zz")
        }
    }

    @Test("bundled theme catalog loads standard")
    func loadsBundledCatalog() throws {
        let catalog = try ThemeCatalogLoader.loadStrict(
            from: BundleContentResources(bundle: Bundle(for: SokobanPlayController.self))
        )
        #expect(catalog.defaultThemeID == VisualTheme.standardID)
        #expect(catalog.theme(id: VisualTheme.standardID) != nil)
        #expect(catalog.selectableThemes.map(\.id) == [VisualTheme.standardID])
    }

    @Test("unknown keys are rejected by theme codec")
    func rejectsUnknownKeys() throws {
        let json = """
            {
              "schemaVersion": 1,
              "id": "theme.standard",
              "displayNameID": "theme.standard.name",
              "board": {},
              "ui": {},
              "extra": true
            }
            """
        let data = Data(json.utf8)
        #expect(throws: ThemeDecodeError.unknownKeys(["extra"])) {
            _ = try ThemeFileCodec.decodeTheme(data)
        }
    }

    @Test("catalog falls back to built-ins when manifest is missing")
    func catalogFallback() {
        let empty = DirectoryContentResources(root: FileManager.default.temporaryDirectory)
        let catalog = ThemeCatalogLoader.load(from: empty)
        #expect(catalog.theme(id: VisualTheme.standardID)?.id == VisualTheme.standardID)
        #expect(catalog.selectableThemes.map(\.id) == [VisualTheme.standardID])
        #expect(
            catalog.resolvedTheme(preferredID: "theme.missing").id == VisualTheme.standardID
        )
    }
}

@Suite("Phase 3.4 theme settings and renderer")
@MainActor
struct Phase34ThemeIntegrationTests {
    @Test("settings keep standard theme applied to the scene")
    func settingsApplyTheme() throws {
        let bundle = try TestPlayControllerFactory.make(markIntroDismissed: true)
        #expect(bundle.controller.visualTheme.id == VisualTheme.standardID)
        #expect(bundle.controller.scene.themeIDForTesting == VisualTheme.standardID)

        bundle.controller.updateThemeID("theme.missing")
        #expect(bundle.settings.themeID == "theme.missing")
        #expect(bundle.controller.visualTheme.id == VisualTheme.standardID)
        #expect(bundle.controller.scene.themeIDForTesting == VisualTheme.standardID)

        bundle.controller.cycleTheme(by: 1)
        #expect(bundle.controller.visualTheme.id == VisualTheme.standardID)
    }

    @Test("push and completion events produce visible feedback without hard-resync replay")
    func eventFeedbackAndHardResync() throws {
        let scene = SokobanBoardScene(size: CGSize(width: 320, height: 240))
        scene.prefersReducedMotion = true

        let level = try SokobanLevelValidator.level(
            fromASCII: """
                #####
                #@$.#
                #####
                """
        )
        let state0 = try SokobanRules().start(level: level)
        let snap0 = RenderSnapshot.project(state0)
        scene.apply(
            RenderUpdate(
                baseRevision: 0,
                targetRevision: 1,
                snapshot: snap0,
                events: [],
                delivery: .hardResync
            )
        )

        let pushed = try SokobanRules().move(.right, in: state0)
        let snap1 = RenderSnapshot.project(pushed.state)
        scene.apply(
            RenderUpdate(
                baseRevision: 1,
                targetRevision: 2,
                snapshot: snap1,
                events: pushed.events,
                delivery: .animate
            )
        )
        scene.settleAnimationsForTesting()
        #expect(scene.lastEventsForTesting.contains { event in
            if case .objectPushed = event { return true }
            return false
        })

        // Force completion celebration path, then hard-resync must not keep frame.
        scene.apply(
            RenderUpdate(
                baseRevision: 2,
                targetRevision: 3,
                snapshot: snap1,
                events: [.levelCompleted],
                delivery: .animate
            )
        )
        scene.settleAnimationsForTesting()

        scene.apply(
            RenderUpdate(
                baseRevision: 3,
                targetRevision: 4,
                snapshot: snap1,
                events: [.levelCompleted],
                delivery: .hardResync
            )
        )
        #expect(!scene.completionFrameVisibleForTesting)
        #expect(!scene.celebrationVisualsActiveForTesting)
        #expect(scene.settledRevision == 4)
    }

    @Test("celebration settle restores goal colors before undo-style hard-resync")
    func celebrationClearsBeforeHardResync() throws {
        let scene = SokobanBoardScene(size: CGSize(width: 320, height: 240))
        scene.prefersReducedMotion = true
        let level = try SokobanLevelValidator.level(
            fromASCII: """
                #####
                #@$.#
                #####
                """
        )
        let completed = try SokobanRules().move(
            .right,
            in: try SokobanRules().start(level: level)
        )
        let snap = RenderSnapshot.project(completed.state)
        scene.apply(
            RenderUpdate(
                baseRevision: 0,
                targetRevision: 1,
                snapshot: snap,
                events: [],
                delivery: .hardResync
            )
        )
        scene.apply(
            RenderUpdate(
                baseRevision: 1,
                targetRevision: 2,
                snapshot: snap,
                events: [.levelCompleted],
                delivery: .animate
            )
        )
        scene.settleAnimationsForTesting()
        #expect(!scene.completionFrameVisibleForTesting)
        #expect(!scene.celebrationVisualsActiveForTesting)

        let undone = try SokobanRules().start(level: level)
        let snapUndone = RenderSnapshot.project(undone)
        scene.apply(
            RenderUpdate(
                baseRevision: 2,
                targetRevision: 3,
                snapshot: snapUndone,
                events: [],
                delivery: .hardResync
            )
        )
        #expect(!scene.completionFrameVisibleForTesting)
        #expect(!scene.celebrationVisualsActiveForTesting)
    }

    @Test("resize during celebration clears transient presentation")
    func resizeClearsCelebrationPresentation() throws {
        let scene = SokobanBoardScene(size: CGSize(width: 320, height: 240))
        let level = try SokobanLevelValidator.level(
            fromASCII: """
                #####
                #@$.#
                #####
                """
        )
        let completed = try SokobanRules().move(
            .right,
            in: try SokobanRules().start(level: level)
        )
        let snapshot = RenderSnapshot.project(completed.state)
        scene.apply(
            RenderUpdate(
                baseRevision: 0,
                targetRevision: 1,
                snapshot: snapshot,
                events: [],
                delivery: .hardResync
            )
        )
        scene.apply(
            RenderUpdate(
                baseRevision: 1,
                targetRevision: 2,
                snapshot: snapshot,
                events: [.levelCompleted],
                delivery: .animate
            )
        )
        #expect(scene.celebrationVisualsActiveForTesting)

        scene.resize(to: CGSize(width: 480, height: 320))

        #expect(!scene.completionFrameVisibleForTesting)
        #expect(!scene.celebrationVisualsActiveForTesting)
        #expect(scene.settledRevision == 2)
    }

    @Test("board origin stays pixel-aligned for sharp strokes")
    func boardOriginIsPixelAligned() {
        let geometry = GridGeometry(
            availableSize: CGSize(width: 333, height: 211),
            gridWidth: 7,
            gridHeight: 5
        )
        #expect(geometry.boardOrigin.x == geometry.boardOrigin.x.rounded())
        #expect(geometry.boardOrigin.y == geometry.boardOrigin.y.rounded())
        #expect(geometry.tileSize * 7 <= 333 + 0.001)
        #expect(geometry.tileSize * 5 <= 211 + 0.001)
    }

    @Test("standard focus foreground contrasts with focus background")
    func standardFocusForegroundContrasts() {
        let theme = BuiltInThemes.standard
        #expect(theme.ui.focusForeground != theme.ui.focusBackground)
    }

    @Test("settings hide theme picker when only one theme is available")
    func settingsThemeFocusOrderWithoutPicker() {
        let order = SettingsOverlay.keyboardFocusOrder(showsThemePicker: false)
        #expect(order.first == "reduceMotion")
        #expect(!order.contains("theme"))
        #expect(
            KeyboardFocusCycle.move(from: "reduceMotion", in: order, offset: -1) == "back"
        )
    }

    @Test("settings theme row leads focus order when multiple themes exist")
    func settingsThemeFocusOrderWithPicker() {
        let order = SettingsOverlay.keyboardFocusOrder(showsThemePicker: true)
        #expect(order.first == "theme")
        #expect(
            KeyboardFocusCycle.move(from: "theme", in: order, offset: 1) == "reduceMotion"
        )
        #expect(
            KeyboardFocusCycle.move(from: "theme", in: order, offset: -1) == "back"
        )
    }

    @Test("unset settings seed theme from catalog default")
    func seedsCatalogDefaultTheme() {
        let settings = AppSettingsStore.ephemeral()
        #expect(!settings.hasPersistedThemeID)
        let catalog = ThemeCatalog(
            themes: BuiltInThemes.allFallbacks(),
            defaultThemeID: VisualTheme.standardID
        )
        settings.seedThemeIDFromCatalogIfUnset(catalog.defaultThemeID)
        #expect(settings.themeID == VisualTheme.standardID)
        #expect(settings.hasPersistedThemeID)

        settings.seedThemeIDFromCatalogIfUnset("theme.other")
        #expect(settings.themeID == VisualTheme.standardID)
    }
}
