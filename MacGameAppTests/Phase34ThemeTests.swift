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

    @Test("bundled theme catalog loads dungeon and kenney")
    func loadsBundledCatalog() throws {
        let catalog = try ThemeCatalogLoader.loadStrict(
            from: BundleContentResources(bundle: Bundle(for: SokobanPlayController.self))
        )
        #expect(catalog.defaultThemeID == VisualTheme.dungeonID)
        #expect(catalog.theme(id: VisualTheme.dungeonID) != nil)
        #expect(catalog.theme(id: VisualTheme.kenneyID) != nil)
        #expect(catalog.theme(id: VisualTheme.standardID) == nil)
        #expect(
            catalog.selectableThemes.map(\.id) == [VisualTheme.dungeonID, VisualTheme.kenneyID]
        )
        #expect(catalog.theme(id: VisualTheme.dungeonID)?.rendering.profile == .pixelInteger)
        #expect(catalog.theme(id: VisualTheme.dungeonID)?.rendering.maxIntegerScale == 0)
        #expect(
            catalog.resolvedTheme(preferredID: VisualTheme.standardID).id == VisualTheme.dungeonID
        )
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

    @Test("missing rendering defaults to vectorContinuous")
    func missingRenderingDefaultsToVector() throws {
        let theme = try ThemeFileCodec.decodeTheme(Data(Self.minimalThemeJSON().utf8))
        #expect(theme.rendering.profile == .vectorContinuous)
        #expect(theme.rendering.baseTilePoints == 32)
        #expect(theme.rendering.textures == nil)
    }

    @Test("explicit vectorContinuous rendering is accepted without textures")
    func explicitVectorRendering() throws {
        let json = Self.minimalThemeJSON(rendering: """
              "rendering": {
                "profile": "vectorContinuous",
                "baseTilePoints": 32
              }
            """)
        let theme = try ThemeFileCodec.decodeTheme(Data(json.utf8))
        #expect(theme.rendering.profile == .vectorContinuous)
        #expect(theme.rendering.textures == nil)
    }

    @Test("pixelInteger rendering requires textures and accepts known keys")
    func pixelIntegerRenderingDecode() throws {
        let json = Self.minimalThemeJSON(id: "theme.dungeon", rendering: """
              "rendering": {
                "profile": "pixelInteger",
                "baseTilePoints": 32,
                "textures": {
                  "floor": "Textures/dungeon/floor.png",
                  "wall": "Textures/dungeon/wall.png",
                  "goal": "Textures/dungeon/goal.png",
                  "player": "Textures/dungeon/player.png",
                  "crate": "Textures/dungeon/crate.png",
                  "crateOnGoal": "Textures/dungeon/crate-on-goal.png"
                }
              }
            """)
        let theme = try ThemeFileCodec.decodeTheme(Data(json.utf8))
        #expect(theme.rendering.profile == .pixelInteger)
        #expect(theme.rendering.baseTilePoints == 32)
        #expect(theme.rendering.maxIntegerScale == 0)
        #expect(theme.rendering.textures?.floor == "Textures/dungeon/floor.png")
        #expect(theme.rendering.textures?.crateOnGoal == "Textures/dungeon/crate-on-goal.png")
    }

    @Test("pixelInteger without textures is rejected")
    func pixelIntegerRequiresTextures() throws {
        let json = Self.minimalThemeJSON(rendering: """
              "rendering": {
                "profile": "pixelInteger",
                "baseTilePoints": 32
              }
            """)
        #expect(throws: ThemeDecodeError.missingTextures) {
            _ = try ThemeFileCodec.decodeTheme(Data(json.utf8))
        }
    }

    @Test("invalid rendering profile is rejected")
    func rejectsInvalidRenderingProfile() throws {
        let json = Self.minimalThemeJSON(rendering: """
              "rendering": {
                "profile": "crtScanlines"
              }
            """)
        #expect(throws: ThemeDecodeError.invalidRenderingProfile("crtScanlines")) {
            _ = try ThemeFileCodec.decodeTheme(Data(json.utf8))
        }
    }

    @Test("unknown rendering keys are rejected")
    func rejectsUnknownRenderingKeys() throws {
        let json = Self.minimalThemeJSON(rendering: """
              "rendering": {
                "profile": "vectorContinuous",
                "filter": "nearest"
              }
            """)
        #expect(throws: ThemeDecodeError.unknownKeys(["filter"])) {
            _ = try ThemeFileCodec.decodeTheme(Data(json.utf8))
        }
    }

    @Test("broken sole theme.dungeon falls back to built-in standard via load()")
    func catalogSkipsBrokenDungeon() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("theme-dungeon-skip-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let themesDir = root.appendingPathComponent("Themes", isDirectory: true)
        try FileManager.default.createDirectory(at: themesDir, withIntermediateDirectories: true)

        let manifest = """
            {
              "schemaVersion": 1,
              "themes": ["Themes/theme.dungeon.json"],
              "defaultThemeID": "theme.dungeon"
            }
            """
        try Data(manifest.utf8).write(to: themesDir.appendingPathComponent("manifest.json"))

        let dungeon = Self.minimalThemeJSON(id: "theme.dungeon", rendering: """
              "rendering": {
                "profile": "pixelInteger",
                "baseTilePoints": 32,
                "textures": {
                  "floor": "Textures/missing/floor.png",
                  "wall": "Textures/missing/wall.png",
                  "goal": "Textures/missing/goal.png",
                  "player": "Textures/missing/player.png",
                  "crate": "Textures/missing/crate.png",
                  "crateOnGoal": "Textures/missing/crate-on-goal.png"
                }
              }
            """)
        try Data(dungeon.utf8).write(to: themesDir.appendingPathComponent("theme.dungeon.json"))

        let catalog = ThemeCatalogLoader.load(from: DirectoryContentResources(root: root))
        #expect(catalog.selectableThemes.map(\.id) == [VisualTheme.standardID])
        #expect(catalog.theme(id: VisualTheme.dungeonID) == nil)
        #expect(catalog.defaultThemeID == VisualTheme.standardID)
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

    @Test("built-in standard uses vectorContinuous rendering")
    func builtInStandardRendering() {
        #expect(BuiltInThemes.standard.rendering.profile == .vectorContinuous)
        #expect(BuiltInThemes.standard.rendering.textures == nil)
        #expect(VisualTheme.knownIDs == [
            VisualTheme.standardID, VisualTheme.dungeonID, VisualTheme.kenneyID,
        ])
        #expect(VisualTheme.optionalPixelIDs == [VisualTheme.dungeonID, VisualTheme.kenneyID])
    }

    /// Minimal valid theme JSON; optional `rendering` fragment (include quotes/object only).
    private static func minimalThemeJSON(
        id: String = "theme.standard",
        rendering: String? = nil
    ) -> String {
        let renderingBlock = rendering.map { ",\n\($0)" } ?? ""
        return """
            {
              "schemaVersion": 1,
              "id": "\(id)",
              "displayNameID": "\(id).name",
              "board": {
                "background": "#1E1E1E",
                "terrain": {
                  "voidFill": "#0A0A0A",
                  "floorFill": "#38473D",
                  "floorStroke": "#4A5C50",
                  "wallFill": "#736659",
                  "wallStroke": "#E8E0D8",
                  "wallSymbol": "▦",
                  "goalFill": "#2F6F86",
                  "goalStroke": "#D8F0F8",
                  "goalSymbol": "◎"
                },
                "entities": {
                  "playerFill": "#F2BF33",
                  "playerStroke": "#FFF4C8",
                  "playerSymbol": "◆",
                  "crateFill": "#C45A2C",
                  "crateStroke": "#FFE0C8",
                  "crateSymbol": "■"
                },
                "stateMarkers": {
                  "crateOnGoalSymbol": "✓",
                  "crateOnGoalColor": "#FFFFFF",
                  "playerOnGoalSymbol": "✓",
                  "playerOnGoalColor": "#FFFFFF",
                  "emptyGoalAccent": "#9ED7E8"
                },
                "feedback": {
                  "blockedSymbol": "×",
                  "blockedColor": "#FF5A5A",
                  "goalEnteredSymbol": "✓",
                  "goalEnteredColor": "#55E08A",
                  "goalLeftSymbol": "↶",
                  "goalLeftColor": "#FFB04A",
                  "pushHighlight": "#FFFFFF",
                  "completionFrame": "#55E08A"
                }
              },
              "ui": {
                "focusRing": "#5CB0FF",
                "focusBackground": "#1A3A5C",
                "focusBorder": "#8AC8FF",
                "focusForeground": "#FFFFFF",
                "primaryFill": "#3A7BD5",
                "primaryForeground": "#FFFFFF",
                "secondaryFill": "#3A3A3A",
                "secondaryForeground": "#EEEEEE",
                "disabledFill": "#2A2A2A",
                "disabledForeground": "#777777",
                "success": "#3DDC84",
                "warning": "#F5A623",
                "error": "#E74C3C",
                "overlayScrim": "#00000073",
                "panelBackground": "#2A2A2AF2",
                "panelForeground": "#F2F2F2",
                "panelSecondary": "#B0B0B0",
                "hudBackground": "#1A1A1ACC",
                "hudForeground": "#F0F0F0",
                "hudSecondary": "#A8A8A8"
              }\(renderingBlock)
            }
            """
    }
}

@Suite("Phase 3.4 theme settings and renderer")
@MainActor
struct Phase34ThemeIntegrationTests {
    @Test("settings default to dungeon; picker cycles to kenney; vector via code switch")
    func settingsApplyTheme() throws {
        let previous = DevVisualThemeSwitch.forceVectorStandard
        defer { DevVisualThemeSwitch.forceVectorStandard = previous }

        DevVisualThemeSwitch.forceVectorStandard = false
        let bundle = try TestPlayControllerFactory.make(markIntroDismissed: true)
        #expect(bundle.controller.visualTheme.id == VisualTheme.dungeonID)
        #expect(bundle.controller.scene.themeIDForTesting == VisualTheme.dungeonID)
        #expect(bundle.controller.scene.renderingProfileForTesting == .pixelInteger)
        #expect(bundle.controller.settingsPresentation.themeOptions.count == 2)

        bundle.controller.updateThemeID("theme.missing")
        #expect(bundle.settings.themeID == "theme.missing")
        #expect(bundle.controller.visualTheme.id == VisualTheme.dungeonID)

        bundle.controller.cycleTheme(by: 1)
        #expect(bundle.controller.visualTheme.id == VisualTheme.kenneyID)
        #expect(bundle.controller.scene.renderingProfileForTesting == .pixelInteger)

        bundle.controller.cycleTheme(by: 1)
        #expect(bundle.controller.visualTheme.id == VisualTheme.dungeonID)

        DevVisualThemeSwitch.forceVectorStandard = true
        let forced = try TestPlayControllerFactory.make(markIntroDismissed: true)
        #expect(forced.controller.visualTheme.id == VisualTheme.standardID)
        #expect(forced.controller.scene.renderingProfileForTesting == .vectorContinuous)
    }

    @Test("dungeon theme draws pixel textures")
    func dungeonPixelBoard() throws {
        let catalog = try ThemeCatalogLoader.loadStrict(
            from: BundleContentResources(bundle: Bundle(for: SokobanPlayController.self))
        )
        guard let dungeon = catalog.theme(id: VisualTheme.dungeonID) else {
            Issue.record("theme.dungeon missing from bundled catalog")
            return
        }

        let scene = SokobanBoardScene(size: CGSize(width: 640, height: 480))
        scene.apply(theme: dungeon)
        #expect(scene.renderingProfileForTesting == .pixelInteger)

        let level = try SokobanLevelValidator.level(
            fromASCII: """
                #####
                #@$.#
                #####
                """
        )
        let state = try SokobanRules().start(level: level)
        scene.apply(
            RenderUpdate(
                baseRevision: 0,
                targetRevision: 1,
                snapshot: RenderSnapshot.project(state),
                events: [],
                delivery: .hardResync
            )
        )

        let geometry = scene.geometryForTesting
        #expect(geometry.renderingProfile == .pixelInteger)
        // 5×3 board in 640×480 → continuous fill 128
        #expect(geometry.tileSize == 128)
        #expect(scene.terrainNodeCountForTesting == 15)
        #expect(scene.entityNodeCountForTesting == 2)
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
            themes: [BuiltInThemes.standard],
            defaultThemeID: VisualTheme.dungeonID
        )
        // Catalog default may differ from built-in list; seed writes the ID string.
        settings.seedThemeIDFromCatalogIfUnset(catalog.defaultThemeID)
        #expect(settings.themeID == VisualTheme.dungeonID)
        #expect(settings.hasPersistedThemeID)

        settings.seedThemeIDFromCatalogIfUnset("theme.other")
        #expect(settings.themeID == VisualTheme.dungeonID)
    }
}
