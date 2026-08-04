import AppKit
import GameCore
import SwiftUI

/// App-layer controller for one Sokoban window: session, input, scene, overlays.
@MainActor
final class SokobanPlayController: ObservableObject {
    private static let restartableSupersededTutorialHashes: [String: Set<String>] = [
        "sokoban.tutorial.001": [
            "11d20dcf2b735f52b3522e76d7b22df60fc855563d8754462f80b57d609fc585",
            "d951ac0c0b9114dae245aecabc5befdac913614a096a21f3fd303f0777cfd594",
        ],
    ]

    let scene: SokobanBoardScene
    let router = GameplayInputRouter()
    let audioDirector: AudioDirector
    let runPersistence: SokobanRunPersistence
    let progressPersistence: ProgressPersistence
    let catalog: SokobanContentCatalog
    let caveCatalog: CaveContentCatalog
    let themeCatalog: ThemeCatalog
    let musicTrackCatalog: MusicTrackCatalog
    let settingsStore: AppSettingsStore
    let reduceMotionProvider: ReduceMotionProvider

    private(set) var activePlay: ActivePlaySession?
    private let clock: any MonotonicClock = SystemUptimeClock()

    /// Sokoban session when ``activePlay`` is `.sokoban`; otherwise `nil`.
    var session: GameSession? { activePlay?.sokoban }
    /// Cave session when ``activePlay`` is `.cave`; otherwise `nil`.
    var caveSession: CaveSession? { activePlay?.cave }

    @Published private(set) var presentationPhase: GamePresentationPhase = .playing
    @Published private(set) var levelTitle = ""
    @Published private(set) var tutorialHintText = ""
    @Published private(set) var isCaveMode = false
    /// Which campaign the launch / level-selection menus currently operate on.
    @Published private(set) var shellCampaign: ShellCampaign = .sokoban
    @Published private(set) var moveCount = 0
    @Published private(set) var pushCount = 0
    @Published private(set) var completedGoalCount = 0
    @Published private(set) var totalGoalCount = 0
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var canPause = false
    @Published private(set) var canResume = false
    @Published private(set) var canRestart = false
    @Published private(set) var faultMessage: String?
    /// Blocking recovery copy when a run file cannot be restored.
    @Published private(set) var recoveryMessage: String?
    /// Non-blocking persistence warning; gameplay continues.
    @Published private(set) var persistenceDiagnostic: String?
    @Published private(set) var gameplayNotice: String?
    @Published private(set) var outcomeHint = ""
    @Published private(set) var outcomeTitle = AppStrings.text(.uiOutcomeLevelComplete)
    @Published private(set) var outcomePrimaryAction: OutcomePrimaryAction = .openLaunchMenu
    @Published private(set) var outcomePrimaryTitle = AppStrings.text(.uiOutcomeBack)
    @Published private(set) var outcomeNewBestMoves = false
    @Published private(set) var outcomeNewBestPushes = false
    @Published private(set) var outcomeBestMoveCount: Int?
    @Published private(set) var outcomeBestPushCount: Int?
    /// Keyboard-confirm target while the result overlay is visible.
    @Published private(set) var focusedOutcomeAction: OutcomeFocusedAction = .primary
    /// Game-selection keyboard focus (Sokoban, Höhle-Demo, Hilfe, Settings).
    @Published private(set) var focusedGameSelectionAction: GameSelectionAction = .sokoban
    /// Launch-menu keyboard selection.
    @Published private(set) var focusedLaunchAction: LaunchMenuAction = .continueCampaign
    /// Pause-menu keyboard selection.
    @Published private(set) var focusedPauseAction: PauseMenuAction = .resume
    /// Level-selection keyboard selection (`navigation.back` or a level id).
    @Published private(set) var focusedLevelSelectionID: String = "navigation.back"
    /// Settings keyboard selection id (`theme`, `mute`, `back`, …).
    @Published private(set) var focusedSettingsID: String = SettingsFocusID.back
    /// Where help / settings return when dismissed.
    @Published private(set) var overlayReturnOrigin: OverlayReturnOrigin?
    /// Published mirror so SwiftUI invalidates when the nested settings store changes.
    @Published private(set) var settingsSnapshot: AppSettingsSnapshot = .default
    /// Active visual theme resolved from settings + catalog fallbacks.
    @Published private(set) var visualTheme: VisualTheme = BuiltInThemes.standard

    private var showOutcomeWorkItem: DispatchWorkItem?
    private var recordedCompletionForSession = false
    private var settingsHandlerID: UUID?
    private var appIsActive = true
    private let moveHoldRepeater = SokobanMoveHoldRepeater()
    private let emissions: EmissionApplicator
    private let settingsAudio: SettingsAudioBridge

    private(set) var currentLevelID: String

    init(
        audioDirector: AudioDirector = AudioDirector(),
        runPersistence: SokobanRunPersistence,
        progressPersistence: ProgressPersistence,
        catalog: SokobanContentCatalog,
        caveCatalog: CaveContentCatalog,
        settingsStore: AppSettingsStore = AppSettingsStore(),
        reduceMotionSource: (any SystemReduceMotionSource)? = nil,
        themeCatalog: ThemeCatalog? = nil
    ) {
        self.audioDirector = audioDirector
        let boardScene = SokobanBoardScene(size: CGSize(width: 640, height: 480))
        self.scene = boardScene
        self.emissions = EmissionApplicator(scene: boardScene, audioDirector: audioDirector)
        self.settingsAudio = SettingsAudioBridge(
            audioDirector: audioDirector,
            settingsStore: settingsStore
        )
        self.runPersistence = runPersistence
        self.progressPersistence = progressPersistence
        self.catalog = catalog
        self.caveCatalog = caveCatalog
        self.themeCatalog =
            themeCatalog
            ?? ThemeCatalogLoader.load(
                from: BundleContentResources(bundle: Bundle(for: SokobanPlayController.self))
            )
        self.musicTrackCatalog = MusicTrackCatalogLoader.load(
            from: BundleContentResources(bundle: Bundle(for: SokobanPlayController.self))
        )
        self.settingsStore = settingsStore
        self.reduceMotionProvider = ReduceMotionProvider(
            settings: settingsStore,
            systemSource: reduceMotionSource ?? WorkspaceReduceMotionSource()
        )
        self.currentLevelID = catalog.first.id
        self.runPersistence.onSaveFailure = { [weak self] message in
            self?.persistenceDiagnostic = message
        }
        self.progressPersistence.onSaveFailure = { [weak self] message in
            self?.persistenceDiagnostic = message
        }
        bindMoveHoldRepeater()
        bindSimulationClock()
        refreshPersistenceDiagnostic()
        bindSettingsSideEffects()
        bootstrapFromPersistence()
    }

    /// Loads the bundled cave catalog for call sites that only inject Sokoban content.
    convenience init(
        audioDirector: AudioDirector = AudioDirector(),
        runPersistence: SokobanRunPersistence,
        progressPersistence: ProgressPersistence,
        catalog: SokobanContentCatalog,
        settingsStore: AppSettingsStore = AppSettingsStore(),
        reduceMotionSource: (any SystemReduceMotionSource)? = nil,
        themeCatalog: ThemeCatalog? = nil
    ) {
        let caveCatalog: CaveContentCatalog
        do {
            caveCatalog = try BundleContentLoader.loadCaveCatalog(
                from: Bundle(for: SokobanPlayController.self)
            )
        } catch {
            preconditionFailure("Failed to load bundled cave catalog: \(error)")
        }
        self.init(
            audioDirector: audioDirector,
            runPersistence: runPersistence,
            progressPersistence: progressPersistence,
            catalog: catalog,
            caveCatalog: caveCatalog,
            settingsStore: settingsStore,
            reduceMotionSource: reduceMotionSource,
            themeCatalog: themeCatalog
        )
    }

    /// Loads bundled content; on failure enters a faulted presentation with no session.
    convenience init(
        audioDirector: AudioDirector = AudioDirector(),
        runPersistence: SokobanRunPersistence,
        progressPersistence: ProgressPersistence,
        bundle: Bundle = Bundle(for: SokobanPlayController.self),
        settingsStore: AppSettingsStore = AppSettingsStore()
    ) {
        do {
            let catalog = try BundleContentLoader.loadSokobanCatalog(from: bundle)
            let caveCatalog = try BundleContentLoader.loadCaveCatalog(from: bundle)
            self.init(
                audioDirector: audioDirector,
                runPersistence: runPersistence,
                progressPersistence: progressPersistence,
                catalog: catalog,
                caveCatalog: caveCatalog,
                settingsStore: settingsStore
            )
        } catch {
            self.init(
                audioDirector: audioDirector,
                runPersistence: runPersistence,
                progressPersistence: progressPersistence,
                contentLoadFailureMessage: "Failed to load game content: \(error)",
                settingsStore: settingsStore
            )
        }
    }

    init(
        audioDirector: AudioDirector,
        runPersistence: SokobanRunPersistence,
        progressPersistence: ProgressPersistence,
        contentLoadFailureMessage: String,
        settingsStore: AppSettingsStore = AppSettingsStore(),
        reduceMotionSource: (any SystemReduceMotionSource)? = nil
    ) {
        self.audioDirector = audioDirector
        let boardScene = SokobanBoardScene(size: CGSize(width: 640, height: 480))
        self.scene = boardScene
        self.emissions = EmissionApplicator(scene: boardScene, audioDirector: audioDirector)
        self.settingsAudio = SettingsAudioBridge(
            audioDirector: audioDirector,
            settingsStore: settingsStore
        )
        self.runPersistence = runPersistence
        self.progressPersistence = progressPersistence
        self.catalog = SokobanContentCatalog(
            campaignID: "",
            levels: [],
            strings: ContentStringTable(values: [:]),
            defaultThemeID: nil,
            defaultAudioThemeID: nil
        )
        self.caveCatalog = CaveContentCatalog(
            campaignID: "",
            levels: [],
            strings: ContentStringTable(values: [:])
        )
        self.themeCatalog = ThemeCatalog(
            themes: BuiltInThemes.allFallbacks(),
            defaultThemeID: VisualTheme.standardID
        )
        self.musicTrackCatalog = MusicTrackCatalog(
            tracks: BuiltInMusicTracks.allFallbacks(),
            defaultTrackIDs: BuiltInMusicTracks.defaultTrackIDs()
        )
        self.settingsStore = settingsStore
        self.reduceMotionProvider = ReduceMotionProvider(
            settings: settingsStore,
            systemSource: reduceMotionSource ?? WorkspaceReduceMotionSource()
        )
        self.currentLevelID = ""
        self.activePlay = nil
        self.presentationPhase = .faulted
        self.faultMessage = contentLoadFailureMessage
        self.router.enterModalBlocked()
        self.audioDirector.reset()
        bindMoveHoldRepeater()
        bindSimulationClock()
        bindSettingsSideEffects()
    }

    private func setActivePlay(_ play: ActivePlaySession?) {
        activePlay = play
        isCaveMode = play?.isCave ?? false
    }

    // MARK: - Presentation models

    var levelIntroPresentation: LevelIntroPresentation {
        if isCaveMode {
            return PresentationFactory.caveLevelIntro(
                title: levelTitle,
                requiredDiamonds: caveSession?.requiredDiamonds ?? 0,
                timeLimitTicks: caveSession?.remainingTicks ?? 0,
                hint: tutorialHintText
            )
        }
        return PresentationFactory.levelIntro(title: levelTitle, body: tutorialHintText)
    }

    var pausePresentation: PausePresentation {
        PresentationFactory.pause(isCaveMode: isCaveMode || shellCampaign == .cave)
    }

    var levelSelectionRows: [LevelSelectionRow] {
        switch shellCampaign {
        case .sokoban:
            return catalog.levels.map { descriptor in
                LevelSelectionRow(
                    id: descriptor.id,
                    title: catalog.title(for: descriptor),
                    availability: levelAvailability(for: descriptor)
                )
            }
        case .cave:
            return caveCatalog.levels.map { descriptor in
                LevelSelectionRow(
                    id: descriptor.id,
                    title: caveCatalog.title(for: descriptor),
                    availability: caveLevelAvailability(for: descriptor)
                )
            }
        }
    }

    var helpPresentation: HelpPresentation {
        PresentationFactory.help(
            isCaveMode: isCaveMode || shellCampaign == .cave,
            catalog: catalog
        )
    }

    var settingsPresentation: SettingsPresentation {
        PresentationFactory.settings(
            snapshot: settingsSnapshot,
            musicTrackCatalog: musicTrackCatalog,
            themeCatalog: themeCatalog,
            selectedThemeID: visualTheme.id
        )
    }

    var outcomePresentation: OutcomePresentation {
        PresentationFactory.outcome(
            PresentationFactory.OutcomeInput(
                isCaveMode: isCaveMode,
                title: outcomeTitle,
                hint: outcomeHint,
                primaryTitle: outcomePrimaryTitle,
                moveCount: moveCount,
                pushCount: pushCount,
                completedGoalCount: completedGoalCount,
                totalGoalCount: totalGoalCount,
                canRestart: canRestart,
                canUndo: canUndo,
                bestMoveCount: outcomeBestMoveCount,
                bestPushCount: outcomeBestPushCount,
                newBestMoves: outcomeNewBestMoves,
                newBestPushes: outcomeNewBestPushes
            )
        )
    }

    var boardAccessibilityLabel: String {
        PresentationFactory.boardAccessibilityLabel(levelTitle: levelTitle)
    }

    var boardAccessibilityValue: String {
        PresentationFactory.boardAccessibilityValue(
            snapshot: scene.currentSnapshot,
            isCaveMode: isCaveMode
        )
    }

    // MARK: - Lifecycle

    /// Loads a catalog level without consulting the run file (explicit next / recovery).
    ///
    /// Shows an explicit-dismiss level intro for an unseen tutorial hint. In-session
    /// restart keeps the existing session and does not call this path.
    func startLevel(id: String? = nil, showIntro: Bool? = nil) {
        clearMoveHold()
        cancelShowOutcome()
        audioDirector.reset()
        applyAudioSettingsFromStore()
        scene.prepareForNewSession()
        recoveryMessage = nil
        gameplayNotice = nil
        shellCampaign = .sokoban
        refreshPersistenceDiagnostic()

        let levelID = id ?? currentLevelID
        guard let descriptor = catalog.descriptor(id: levelID) else {
            setActivePlay(nil)
            presentationPhase = .faulted
            faultMessage = "Unknown level: \(levelID)"
            router.enterModalBlocked()
            audioDirector.reset()
            refreshPublishedState()
            return
        }

        do {
            let level = descriptor.makeLevel()
            let newSession = try GameSession(
                level: level,
                levelID: descriptor.id,
                contentHash: descriptor.contentHash,
                saveSink: runPersistence
            )
            let resolvedShowIntro = shouldShowIntro(for: descriptor, override: showIntro)
            bootstrapSession(newSession, descriptor: descriptor, showIntro: resolvedShowIntro)
        } catch {
            setActivePlay(nil)
            presentationPhase = .faulted
            faultMessage = "Failed to load level: \(error)"
            router.enterModalBlocked()
            audioDirector.reset()
            refreshPublishedState()
        }
    }

    /// Clears a bad run and starts catalog level 1.
    func beginFreshRunFromRecovery() {
        runPersistence.removeRunFile()
        recoveryMessage = nil
        guard let first = catalog.levels.first else {
            presentationPhase = .faulted
            faultMessage = "No levels available."
            router.enterModalBlocked()
            return
        }
        currentLevelID = first.id
        startLevel(id: first.id, showIntro: true)
    }

    /// Dismisses the level-intro overlay and begins accepting moves.
    ///
    /// Cave sessions stay in ``SessionPhase/ready`` until the first gameplay
    /// intent; Sokoban enters ``SessionPhase/playing`` via the existing session.
    func dismissLevelIntro() {
        guard presentationPhase == .levelIntro else { return }
        if !isCaveMode {
            markCurrentIntroHintSeen()
        }
        presentationPhase = .playing
        router.enterGameplay()
        // Focus may have been lost during intro; ensure playback is audible again.
        if appIsActive {
            audioDirector.resumePlayback()
        }
        refreshPublishedState()
    }

    // MARK: - Input

    /// Routes a platform key event. Returns `true` when the event was consumed.
    @discardableResult
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard presentationPhase != .faulted, presentationPhase != .runRecovery else {
            return false
        }
        if handleMoveHoldKeyUp(event) {
            return true
        }
        switch router.routeDecision(event) {
        case .unhandled:
            return handleOverlayMenuKeyEvent(event)
        case .consumed:
            return true
        case .routed(let routed):
            switch routed {
            case .gameplay(let intent):
                handleGameplay(intent, keyCode: event.keyCode)
            case .outcomeAction:
                handleOutcomeAction()
            case .dismissIntro:
                dismissLevelIntro()
            }
            return true
        }
    }

    private func bindMoveHoldRepeater() {
        moveHoldRepeater.onFire = { [weak self] direction in
            self?.performHeldMove(direction)
        }
    }

    private func bindSimulationClock() {
        scene.onSimulationFrame = { [weak self] in
            self?.advanceCaveSimulation()
        }
    }

    private func advanceCaveSimulation() {
        guard case .cave(let caveSession) = activePlay else { return }
        guard presentationPhase == .playing else { return }
        guard caveSession.phase == .playing || caveSession.phase == .ready else { return }
        guard let emission = caveSession.advance(to: clock.now()) else { return }
        emissions.apply(emission)
        applyEmissionSideEffects(emission)
        refreshPublishedState()
    }

    private func handleMoveHoldKeyUp(_ event: NSEvent) -> Bool {
        guard event.type == .keyUp else { return false }
        guard let direction = InputMapper.moveDirection(keyCode: event.keyCode) else { return false }
        moveHoldRepeater.noteKeyUp(keyCode: event.keyCode)
        if case .cave(let caveSession) = activePlay {
            caveSession.noteDirectionUp(direction)
        }
        return true
    }

    private func clearMoveHold() {
        moveHoldRepeater.clear()
    }

    private func performHeldMove(_ direction: Direction) {
        guard presentationPhase == .playing, let session, session.phase == .playing else {
            clearMoveHold()
            return
        }
        let results = session.submitMove(direction)
        applyResults(results)
        gameplayNotice = session.preventedStaticDeadlockOnLastMove
            ? AppStrings.text(.uiDeadlockPrevented)
            : nil
    }

    /// Menu navigation / activate / cancel owned by the local key monitor path.
    private func handleOverlayMenuKeyEvent(_ event: NSEvent) -> Bool {
        if handleUnlockCheatKey(event) {
            return true
        }
        guard let command = OverlayMenuCommandMapper.command(from: event) else {
            return false
        }
        let result = OverlayMenuNavigator.resolve(
            phase: presentationPhase,
            command: command,
            isRepeat: event.isARepeat,
            focus: overlayFocusState,
            context: overlayNavigationContext
        )
        return applyOverlayNavigationResult(result)
    }

    /// Debug/cheat: `U` unlocks all levels for the active shell campaign.
    @discardableResult
    private func handleUnlockCheatKey(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, !event.isARepeat else { return false }
        guard event.keyCode == KeyCode.u else { return false }
        let blocking: NSEvent.ModifierFlags = [.command, .control, .option]
        guard event.modifierFlags.intersection(blocking).isEmpty else { return false }

        switch presentationPhase {
        case .launchMenu, .levelSelection:
            unlockAllLevelsForShellCampaign()
            return true
        case .playing, .paused, .levelIntro, .outcomeAwaitingChoice:
            if isCaveMode || shellCampaign == .cave {
                unlockAllLevelsForShellCampaign()
                return true
            }
            if shellCampaign == .sokoban {
                unlockAllLevelsForShellCampaign()
                return true
            }
            return false
        default:
            return false
        }
    }

    private func unlockAllLevelsForShellCampaign() {
        switch shellCampaign {
        case .sokoban:
            progressPersistence.unlockAllLevels(catalog.levels.map(\.id))
        case .cave:
            progressPersistence.unlockAllCaveLevels(caveCatalog.levels.map(\.id))
        }
        gameplayNotice = AppStrings.text(.uiCheatLevelsUnlocked)
        if presentationPhase == .levelSelection {
            focusedLevelSelectionID =
                levelSelectionFocusOrder.first ?? Self.levelSelectionBackID
        }
        refreshPublishedState()
    }

    private var overlayFocusState: OverlayFocusState {
        OverlayFocusState(
            gameSelection: focusedGameSelectionAction,
            launch: focusedLaunchAction,
            pause: focusedPauseAction,
            levelSelectionID: focusedLevelSelectionID,
            settingsID: focusedSettingsID,
            outcome: focusedOutcomeAction
        )
    }

    private var overlayNavigationContext: OverlayNavigationContext {
        OverlayNavigationContext(
            levelSelectionOrder: levelSelectionFocusOrder,
            settingsOrder: settingsFocusOrder,
            outcomeOrder: outcomeFocusOrder,
            musicTrackFocusGames: Dictionary(
                uniqueKeysWithValues: settingsPresentation.musicTrackGroups.map { ($0.id, $0.game) }
            ),
            levelSelectionBackID: Self.levelSelectionBackID
        )
    }

    private var outcomeFocusOrder: [OutcomeFocusedAction] {
        var actions: [OutcomeFocusedAction] = [.primary]
        if canRestart {
            actions.append(.again)
        }
        if canUndo {
            actions.append(.undo)
        }
        actions.append(.levelSelection)
        return actions
    }

    private var levelSelectionFocusOrder: [String] {
        levelSelectionRows.compactMap { row in
            row.availability == .locked ? nil : row.id
        } + [Self.levelSelectionBackID]
    }

    private var settingsFocusOrder: [String] {
        SettingsFocusID.keyboardFocusOrder(
            showsThemePicker: themeCatalog.selectableThemes.count > 1,
            musicTrackFocusIDs: settingsPresentation.musicTrackGroups.map(\.id)
        )
    }

    private static let levelSelectionBackID = "navigation.back"

    @discardableResult
    private func applyOverlayNavigationResult(_ result: OverlayNavigationResult) -> Bool {
        switch result {
        case .unhandled:
            return false
        case .consumed:
            return true
        case .updateFocus(let focus):
            applyOverlayFocus(focus)
            return true
        case .action(let action):
            applyOverlayNavigationAction(action)
            return true
        }
    }

    private func applyOverlayFocus(_ focus: OverlayFocusState) {
        focusedGameSelectionAction = focus.gameSelection
        focusedLaunchAction = focus.launch
        focusedPauseAction = focus.pause
        focusedLevelSelectionID = focus.levelSelectionID
        focusedSettingsID = focus.settingsID
        setFocusedOutcomeAction(focus.outcome)
    }

    private func applyOverlayNavigationAction(_ action: OverlayNavigationAction) {
        switch action {
        case .activateGameSelection:
            performFocusedGameSelectionAction()
        case .activateLaunch:
            performFocusedLaunchAction()
        case .activatePause:
            performFocusedPauseAction()
        case .activateLevelSelection:
            performFocusedLevelSelectionAction()
        case .cycleTheme(let offset):
            cycleTheme(by: offset)
        case .cycleMusicTrack(let game, let offset):
            cycleMusicTrack(for: game, by: offset)
        case .toggleReduceMotion:
            updateReduceMotionEnabled(!settingsStore.reduceMotionEnabled)
        case .toggleMute:
            updateMuted(!settingsStore.isMuted)
        case .dismissHelpOrSettings:
            dismissHelpOrSettings()
        case .cancelPauseToGameSelection:
            openGameSelection()
        case .cancelLaunchToGameSelection:
            returnToGameSelectionFromLaunchMenu()
        case .cancelLevelSelectionToLaunch:
            returnToLaunchMenu()
        case .performOutcomePrimary:
            performOutcomePrimaryAction()
        }
    }

    private func performFocusedGameSelectionAction() {
        switch focusedGameSelectionAction {
        case .sokoban:
            selectSokobanFromGameSelection()
        case .cave:
            selectCaveFromGameSelection()
        case .help:
            openHelpFromGameSelection()
        case .settings:
            openSettingsFromGameSelection()
        }
    }

    private func performFocusedLaunchAction() {
        switch focusedLaunchAction {
        case .continueCampaign:
            continueCampaign()
        case .selectLevel:
            openLevelSelection()
        case .help:
            openHelpFromLaunchMenu()
        case .settings:
            openSettingsFromLaunchMenu()
        case .resetProgress:
            resetCampaignProgressFromLaunchMenu()
        case .backToGameSelection:
            returnToGameSelectionFromLaunchMenu()
        }
    }

    private func performFocusedPauseAction() {
        switch focusedPauseAction {
        case .resume:
            resumeFromPauseOverlay()
        case .restart:
            restartFromPauseOverlay()
        case .settings:
            openSettingsFromPause()
        case .levelSelection:
            openLevelSelectionFromPauseOverlay()
        case .help:
            openHelpFromPause()
        }
    }

    private func performFocusedLevelSelectionAction() {
        if focusedLevelSelectionID == Self.levelSelectionBackID {
            returnToLaunchMenu()
        } else {
            startSelectedLevel(id: focusedLevelSelectionID)
        }
    }

    private func resetOverlayFocus(for phase: GamePresentationPhase) {
        applyOverlayFocus(
            OverlayMenuNavigator.resetFocus(
                for: phase,
                focus: overlayFocusState,
                context: overlayNavigationContext
            )
        )
    }

    func handleAppDeactivation() {
        appIsActive = false
        clearMoveHold()
        router.clearPendingInputs()
        audioDirector.interrupt()
        Task { await runPersistence.flush() }

        guard let play = activePlay, presentationPhase == .playing else { return }
        // Only pause when the player is actively playing — not during intro.
        if play.canEnterPauseFromPlaying {
            pauseFromShell(alreadyInterrupted: true)
        }
    }

    /// Restores audible music after focus return when the shell stayed interactive
    /// without entering pause (outcome or level intro).
    ///
    /// Pause stays interrupted until the player explicitly resumes; the pause
    /// overlay reclaims keyboard focus so Return can activate „Fortsetzen“.
    func handleAppActivation() {
        appIsActive = true
        switch presentationPhase {
        case .outcomeAwaitingChoice:
            audioDirector.resumePlayback()
        case .levelIntro:
            audioDirector.resumePlayback()
        case .paused:
            requestPauseOverlayFocus()
        case .help, .settings:
            if overlayReturnOrigin == .paused {
                requestPauseOverlayFocus()
            }
        case .playing, .gameSelection, .launchMenu, .levelSelection, .faulted, .runRecovery:
            break
        }
    }

    // MARK: - Shared command API (keyboard, overlay, menu)

    func undo() {
        guard canUndo else { return }
        guard presentationPhase != .help, presentationPhase != .settings else { return }
        resumeIfPaused()
        applySessionCommand(.undo)
    }

    func redo() {
        guard canRedo else { return }
        guard presentationPhase != .help, presentationPhase != .settings else { return }
        resumeIfPaused()
        applySessionCommand(.redo)
    }

    func restart() {
        guard canRestart else { return }
        guard presentationPhase != .help, presentationPhase != .settings else { return }
        if isCaveMode {
            restartCave()
            return
        }
        resumeIfPaused()
        clearCompletionRecordingState()
        cancelShowOutcome()
        if presentationPhase == .levelIntro {
            // Restart from intro dismisses without re-showing; hint is marked seen.
            dismissLevelIntro()
        }
        applySessionCommand(.restart)
    }

    private func restartCave() {
        guard let caveSession else { return }
        clearMoveHold()
        clearCompletionRecordingState()
        cancelShowOutcome()
        let emission = caveSession.restart()
        emissions.apply(emission)
        presentationPhase = .playing
        router.enterGameplay()
        if appIsActive {
            audioDirector.resumePlayback()
        }
        refreshPublishedState()
    }

    func togglePause() {
        if presentationPhase == .paused {
            // Esc while paused → Spielauswahl (resume only via „Fortsetzen“).
            openGameSelection()
            return
        }
        guard presentationPhase == .playing else { return }
        pauseFromShell()
    }

    func resumeFromPauseOverlay() {
        resumeFromShell()
    }

    func restartFromPauseOverlay() {
        restart()
    }

    func openLevelSelectionFromPauseOverlay() {
        guard presentationPhase == .paused else { return }
        if isCaveMode {
            shellCampaign = .cave
            openLevelSelection()
        } else {
            openGameSelection()
        }
    }

    func openHelpFromPause() {
        guard presentationPhase == .paused else { return }
        openHelp(returningTo: .paused)
    }

    func openSettingsFromPause() {
        guard presentationPhase == .paused else { return }
        openSettings(returningTo: .paused)
    }

    func openHelpFromGameSelection() {
        guard presentationPhase == .gameSelection else { return }
        openHelp(returningTo: .gameSelection)
    }

    func openSettingsFromGameSelection() {
        guard presentationPhase == .gameSelection else { return }
        openSettings(returningTo: .gameSelection)
    }

    func openHelpFromLaunchMenu() {
        guard presentationPhase == .launchMenu else { return }
        openHelp(returningTo: .launchMenu)
    }

    func openSettingsFromLaunchMenu() {
        guard presentationPhase == .launchMenu else { return }
        openSettings(returningTo: .launchMenu)
    }

    func dismissHelpOrSettings() {
        guard presentationPhase == .help || presentationPhase == .settings else { return }
        guard let origin = overlayReturnOrigin else {
            openGameSelection()
            return
        }
        overlayReturnOrigin = nil
        switch origin {
        case .gameSelection:
            presentationPhase = .gameSelection
            router.enterModalBlocked()
            resetOverlayFocus(for: .gameSelection)
        case .launchMenu:
            presentationPhase = .launchMenu
            router.enterModalBlocked()
            resetOverlayFocus(for: .launchMenu)
        case .paused:
            presentationPhase = .paused
            router.enterPaused()
            requestPauseOverlayFocus()
        }
        refreshPublishedState()
    }

    func openGameSelection() {
        teardownSessionForNavigation(phase: .gameSelection)
    }

    func openLaunchMenu() {
        teardownSessionForNavigation(phase: .launchMenu)
    }

    /// Enters Sokoban from the top-level picker.
    func selectSokobanFromGameSelection() {
        guard presentationPhase == .gameSelection else { return }
        shellCampaign = .sokoban
        setActivePlay(nil)
        if progressPersistence.file.isFreshCampaign {
            startLevel(id: catalog.first.id, showIntro: true)
        } else {
            openLaunchMenu()
        }
    }

    /// Enters Cave from the top-level picker.
    func selectCaveFromGameSelection() {
        guard presentationPhase == .gameSelection else { return }
        shellCampaign = .cave
        setActivePlay(nil)
        if progressPersistence.isFreshCaveCampaign {
            startCaveLevel(id: caveCatalog.first.id)
        } else {
            openLaunchMenu()
        }
    }

    private func startCaveLevel(id: String) {
        guard let descriptor = caveCatalog.descriptor(id: id) else {
            setActivePlay(nil)
            faultMessage = "Unknown cave level: \(id)"
            presentationPhase = .faulted
            router.enterModalBlocked()
            refreshPublishedState()
            return
        }

        do {
            let level = descriptor.makeLevel()
            let newSession = try CaveSession(level: level, levelID: descriptor.id)
            clearMoveHold()
            cancelShowOutcome()
            clearCompletionRecordingState()
            scene.prepareForNewSession()
            scene.presentsCaveContent = true
            audioDirector.reset()
            applyAudioSettingsFromStore()

            let emission = newSession.start()
            setActivePlay(.cave(newSession))
            shellCampaign = .cave
            currentLevelID = descriptor.id
            levelTitle = caveCatalog.title(for: descriptor)
            tutorialHintText = caveCatalog.tutorialHint(for: descriptor)
            faultMessage = nil
            recoveryMessage = nil
            overlayReturnOrigin = nil
            progressPersistence.selectCaveLevel(descriptor.id)
            configureCaveOutcomeActions(for: descriptor.id)

            emissions.apply(emission)
            enterLevelIntro()
            refreshPublishedState()
        } catch {
            setActivePlay(nil)
            faultMessage = "Höhle konnte nicht geladen werden: \(error)"
            presentationPhase = .faulted
            router.enterModalBlocked()
            refreshPublishedState()
        }
    }

    private func configureCaveOutcomeActions(for levelID: String) {
        if let next = caveCatalog.descriptor(after: levelID) {
            outcomePrimaryAction = .nextLevel(id: next.id)
            outcomePrimaryTitle = AppStrings.text(.uiOutcomeNextLevel)
            outcomeTitle = AppStrings.text(.uiOutcomeLevelComplete)
            outcomeHint = AppStrings.text(.uiOutcomeHintCave)
        } else {
            outcomePrimaryAction = .openLaunchMenu
            outcomePrimaryTitle = AppStrings.text(.uiLaunchBackToGames)
            outcomeTitle = AppStrings.text(.uiOutcomeLevelComplete)
            outcomeHint = AppStrings.text(.uiOutcomeHintCave)
        }
    }

    func returnToGameSelectionFromLaunchMenu() {
        guard presentationPhase == .launchMenu else { return }
        openGameSelection()
    }

    func openLevelSelection() {
        teardownSessionForNavigation(phase: .levelSelection)
    }

    func returnToLaunchMenu() {
        guard presentationPhase == .levelSelection else { return }
        presentationPhase = .launchMenu
        router.enterModalBlocked()
        resetOverlayFocus(for: .launchMenu)
        refreshPublishedState()
    }

    func continueCampaign() {
        switch shellCampaign {
        case .sokoban:
            continueSokobanCampaign()
        case .cave:
            continueCaveCampaign()
        }
    }

    private func continueSokobanCampaign() {
        switch runPersistence.load() {
        case .loaded(let file):
            restoreRun(file)
        case .absent:
            let levelID =
                progressPersistence.file.lastSelectedLevelID
                .flatMap { progressPersistence.file.isUnlocked($0) ? $0 : nil }
                ?? catalog.levels.first(where: { progressPersistence.file.isUnlocked($0.id) })?.id
                ?? catalog.first.id
            startSelectedLevel(id: levelID)
        case .invalid(let message, _):
            enterRunRecovery(message: message)
        case .readFailed(let message):
            enterRunRecovery(message: message)
        }
    }

    private func continueCaveCampaign() {
        let levelID =
            progressPersistence.file.lastSelectedCaveLevelID
            .flatMap { progressPersistence.file.isCaveUnlocked($0) ? $0 : nil }
            ?? caveCatalog.levels.first(where: {
                progressPersistence.file.isCaveUnlocked($0.id)
            })?.id
            ?? caveCatalog.first.id
        startSelectedLevel(id: levelID)
    }

    /// Wipes run + campaign progress for the active shell campaign and restarts.
    func resetCampaignProgressFromLaunchMenu() {
        guard presentationPhase == .launchMenu else { return }
        switch shellCampaign {
        case .sokoban:
            runPersistence.removeRunFile()
            progressPersistence.resetToFresh(firstLevelID: catalog.first.id)
            clearCompletionRecordingState()
            startLevel(id: catalog.first.id, showIntro: true)
        case .cave:
            progressPersistence.resetCaveToFresh(
                tutorialLevelIDs: caveCatalog.tutorialLevelIDs
            )
            clearCompletionRecordingState()
            startCaveLevel(id: caveCatalog.first.id)
        }
    }

    func startSelectedLevel(id: String, showIntro: Bool? = nil) {
        switch shellCampaign {
        case .sokoban:
            guard progressPersistence.availability(for: id, in: catalog) != .locked else { return }
            progressPersistence.selectLevel(id)
            startLevel(id: id, showIntro: showIntro)
        case .cave:
            guard progressPersistence.caveAvailability(for: id, in: caveCatalog) != .locked else {
                return
            }
            progressPersistence.selectCaveLevel(id)
            startCaveLevel(id: id)
        }
    }

    func levelAvailability(for descriptor: SokobanLevelDescriptor) -> LevelAvailability {
        progressPersistence.availability(for: descriptor.id, in: catalog)
    }

    func caveLevelAvailability(for descriptor: CaveLevelDescriptor) -> LevelAvailability {
        progressPersistence.caveAvailability(for: descriptor.id, in: caveCatalog)
    }

    func updateReduceMotionEnabled(_ enabled: Bool) {
        settingsStore.reduceMotionEnabled = enabled
    }

    func updateThemeID(_ themeID: String) {
        settingsStore.themeID = themeID
    }

    func cycleTheme(by offset: Int) {
        let options = themeCatalog.selectableThemes
        guard !options.isEmpty else { return }
        let currentIndex = options.firstIndex { $0.id == visualTheme.id } ?? 0
        let count = options.count
        let nextIndex = ((currentIndex + offset) % count + count) % count
        settingsStore.themeID = options[nextIndex].id
    }

    func updateMusicTrackID(_ trackID: String, for game: AudioGameMode = .sokoban) {
        settingsStore.setMusicTrackID(trackID, for: game)
    }

    func cycleMusicTrack(for game: AudioGameMode = .sokoban, by offset: Int) {
        let options = musicTrackCatalog.selectableTracks(for: game)
        guard !options.isEmpty else { return }
        let currentID = settingsStore.musicTrackID(for: game)
        let currentIndex = options.firstIndex { $0.id == currentID } ?? 0
        let count = options.count
        let nextIndex = ((currentIndex + offset) % count + count) % count
        settingsStore.setMusicTrackID(options[nextIndex].id, for: game)
    }

    func updateMusicVolume(_ volume: Double) {
        settingsStore.musicVolume = volume
    }

    func updateEffectsVolume(_ volume: Double) {
        settingsStore.effectsVolume = volume
    }

    func updateMuted(_ muted: Bool) {
        settingsStore.isMuted = muted
    }

    func performOutcomePrimaryAction() {
        guard presentationPhase == .outcomeAwaitingChoice else { return }
        switch outcomePrimaryAction {
        case .nextLevel(let id):
            if isCaveMode {
                startCaveLevel(id: id)
            } else {
                // Variant B: only show intro when the next hint is still unseen.
                startSelectedLevel(id: id)
            }
        case .openLaunchMenu:
            if isCaveMode {
                openGameSelection()
            } else {
                runPersistence.removeRunFile()
                openGameSelection()
            }
        case .playAgain:
            if isCaveMode {
                restartCave()
            } else {
                restartFromOutcomeOverlay()
            }
        }
    }

    /// Confirms the currently focused result-overlay action (Return / Space).
    func performFocusedOutcomeAction() {
        guard presentationPhase == .outcomeAwaitingChoice else { return }
        switch focusedOutcomeAction {
        case .primary:
            performOutcomePrimaryAction()
        case .again:
            restartFromOutcomeOverlay()
        case .undo:
            guard canUndo else { return }
            undoFromOutcomeOverlay()
        case .levelSelection:
            openLevelSelectionFromOutcome()
        }
    }

    /// Keeps router confirm and overlay selection aligned.
    func setFocusedOutcomeAction(_ action: OutcomeFocusedAction) {
        if action == .undo, !canUndo {
            focusedOutcomeAction = .primary
            return
        }
        focusedOutcomeAction = action
    }

    func setFocusedGameSelectionAction(_ action: GameSelectionAction) {
        guard action.isEnabled else { return }
        focusedGameSelectionAction = action
    }

    func setFocusedLaunchAction(_ action: LaunchMenuAction) {
        focusedLaunchAction = action
    }

    func setFocusedPauseAction(_ action: PauseMenuAction) {
        focusedPauseAction = action
    }

    func setFocusedLevelSelectionID(_ id: String) {
        focusedLevelSelectionID = id
    }

    func setFocusedSettingsID(_ id: String) {
        focusedSettingsID = id
    }

    func restartFromOutcomeOverlay() {
        restart()
    }

    func undoFromOutcomeOverlay() {
        guard canUndo else { return }
        undo()
    }

    func openLevelSelectionFromOutcome() {
        guard presentationPhase == .outcomeAwaitingChoice else { return }
        if isCaveMode {
            shellCampaign = .cave
            openLevelSelection()
        } else {
            shellCampaign = .sokoban
            openLevelSelection()
        }
    }

    #if DEBUG
        /// Test helper: skip the post-clear delay and open the result overlay.
        func showOutcomeOverlayNowForTesting() {
            guard session?.phase == .outcomePresenting else { return }
            guard presentationPhase != .outcomeAwaitingChoice else { return }
            enterOutcomeAwaitingChoice()
        }

        /// Test helper: shorten hold-repeat timings.
        func configureMoveHoldForTesting(initialDelay: TimeInterval, repeatInterval: TimeInterval) {
            moveHoldRepeater.initialDelay = initialDelay
            moveHoldRepeater.repeatInterval = repeatInterval
        }
    #endif

    // MARK: - Private bootstrap

    private func bindSettingsSideEffects() {
        settingsStore.seedThemeIDFromCatalogIfUnset(themeCatalog.defaultThemeID)
        settingsStore.seedMusicTrackIDsFromCatalogIfUnset(
            sokobanDefault: musicTrackCatalog.defaultTrackID(for: .sokoban),
            caveDefault: musicTrackCatalog.defaultTrackID(for: .cave)
        )
        settingsSnapshot = settingsStore.snapshot
        settingsAudio.applyFromStore()
        applyVisualThemeFromStore()
        scene.prefersReducedMotion = reduceMotionProvider.isReduceMotionEffective

        settingsHandlerID = settingsStore.addChangeHandler { [weak self] in
            guard let self else { return }
            self.settingsSnapshot = self.settingsStore.snapshot
            self.settingsAudio.applyFromStore()
            self.applyVisualThemeFromStore()
        }

        reduceMotionProvider.onEffectiveChange = { [weak self] effective in
            self?.scene.prefersReducedMotion = effective
        }
        // Push the initial effective value through the callback path.
        reduceMotionProvider.refresh()
    }

    private func applyAudioSettingsFromStore() {
        settingsAudio.applyFromStore()
    }

    private func applyVisualThemeFromStore() {
        let resolved: VisualTheme
        if DevVisualThemeSwitch.forceVectorStandard {
            resolved = BuiltInThemes.standard
        } else {
            resolved = themeCatalog.resolvedTheme(preferredID: settingsStore.themeID)
        }
        visualTheme = resolved
        scene.apply(theme: resolved)
    }

    private func shouldShowIntro(
        for descriptor: SokobanLevelDescriptor,
        override: Bool?
    ) -> Bool {
        if let override { return override }
        guard let hintID = descriptor.tutorialHintID, !hintID.isEmpty else { return false }
        return !progressPersistence.file.hasSeenHint(hintID)
    }

    private func bootstrapFromPersistence() {
        let decision = PlayBootstrapCoordinator.decide(
            loadResult: runPersistence.load(),
            isFreshCampaign: progressPersistence.file.isFreshCampaign
        )
        switch decision {
        case .openGameSelection:
            openGameSelection()
        case .restoreRun(let file):
            restoreRun(file)
        case .enterRecovery(let message):
            enterRunRecovery(message: message)
        }
    }

    private func restoreRun(_ file: SokobanRunFileV1) {
        do {
            let restored = try SokobanRunRestorer.restore(
                file,
                catalogLookup: { [catalog] in catalog.descriptor(id: $0) }
            )
            let newSession = GameSession(restored: restored, saveSink: runPersistence)
            let recoveredStaticDeadlock = restored.recoveredStaticDeadlock
            guard let descriptor = catalog.descriptor(id: restored.levelID) else {
                enterRunRecovery(message: "Saved level is no longer in the catalog.")
                return
            }
            cancelShowOutcome()
            audioDirector.reset()
            applyAudioSettingsFromStore()
            scene.prepareForNewSession()
            // Mid-run restore skips the intro; the player already knows the level.
            bootstrapSession(newSession, descriptor: descriptor, showIntro: false)
            if recoveredStaticDeadlock {
                gameplayNotice = AppStrings.text(.uiDeadlockRecovered)
            }
        } catch {
            if SokobanRunContentChangePolicy.canRestartAfterContentChange(
                file: file,
                error: error,
                levelExists: catalog.descriptor(id: file.levelID) != nil,
                restartableSupersededHashes: Self.restartableSupersededTutorialHashes
            ) {
                // Known tutorial revisions restart in place; a generic content
                // mismatch is only replaced when the run is untouched.
                startLevel(id: file.levelID)
                return
            }
            let message = SokobanRunRestoreMessages.text(for: error)
            _ = runPersistence.quarantineLoadedInvalidFile(message: message)
            enterRunRecovery(message: message)
        }
    }

    private func bootstrapSession(
        _ newSession: GameSession,
        descriptor: SokobanLevelDescriptor,
        showIntro: Bool
    ) {
        let emission = newSession.start()
        setActivePlay(.sokoban(newSession))
        scene.presentsCaveContent = false
        clearCompletionRecordingState()
        currentLevelID = descriptor.id
        faultMessage = nil
        recoveryMessage = nil
        overlayReturnOrigin = nil
        levelTitle = catalog.title(for: descriptor)
        tutorialHintText = catalog.tutorialHint(for: descriptor)
        configureOutcomeActions(for: descriptor.id)
        emissions.apply(emission)
        applyEmissionSideEffects(emission)
        // Restored/completed runs use synchronize (no completion jingle).
        if newSession.phase == .outcomePresenting {
            // Hard-resync has no animation; land on the choice overlay promptly.
            enterOutcomeAwaitingChoice()
        } else if showIntro {
            enterLevelIntro()
        } else {
            presentationPhase = .playing
            router.enterGameplay()
        }
        refreshPublishedState()
    }

    private func enterLevelIntro() {
        clearMoveHold()
        presentationPhase = .levelIntro
        router.enterLevelIntro()
    }

    private func markCurrentIntroHintSeen() {
        if let hintID = catalog.descriptor(id: currentLevelID)?.tutorialHintID {
            progressPersistence.markHintSeen(hintID)
        }
    }

    private func openHelp(returningTo origin: OverlayReturnOrigin) {
        overlayReturnOrigin = origin
        presentationPhase = .help
        router.enterModalBlocked()
        refreshPublishedState()
    }

    private func openSettings(returningTo origin: OverlayReturnOrigin) {
        overlayReturnOrigin = origin
        presentationPhase = .settings
        router.enterModalBlocked()
        resetOverlayFocus(for: .settings)
        refreshPublishedState()
    }

    private func configureOutcomeActions(for levelID: String) {
        if let next = catalog.descriptor(after: levelID) {
            outcomePrimaryAction = .nextLevel(id: next.id)
            outcomePrimaryTitle = AppStrings.text(.uiOutcomeNextLevel)
            outcomeTitle = AppStrings.text(.uiOutcomeLevelComplete)
            outcomeHint = AppStrings.text(.uiOutcomeHintNext)
        } else {
            outcomePrimaryAction = .openLaunchMenu
            outcomePrimaryTitle = AppStrings.text(.uiOutcomeBack)
            outcomeTitle = AppStrings.text(.uiOutcomeTutorialComplete)
            outcomeHint = AppStrings.text(.uiOutcomeHintBack)
        }
    }

    private func enterRunRecovery(message: String) {
        setActivePlay(nil)
        presentationPhase = .runRecovery
        recoveryMessage = message
        faultMessage = nil
        overlayReturnOrigin = nil
        router.enterModalBlocked()
        audioDirector.reset()
        refreshPublishedState()
    }

    private func teardownSessionForNavigation(phase: GamePresentationPhase) {
        clearMoveHold()
        cancelShowOutcome()
        setActivePlay(nil)
        scene.prepareForNewSession()
        audioDirector.reset()
        applyAudioSettingsFromStore()
        presentationPhase = phase
        overlayReturnOrigin = nil
        router.enterModalBlocked()
        resetOverlayFocus(for: phase)
        refreshPublishedState()
    }

    // MARK: - Private gameplay

    private func handleGameplay(_ intent: GameplayIntent, keyCode: UInt16) {
        if isCaveMode {
            handleCaveGameplay(intent, keyCode: keyCode)
            return
        }
        switch intent {
        case .move(let direction):
            guard presentationPhase == .playing, let session, session.phase == .playing else {
                return
            }
            moveHoldRepeater.noteKeyDown(keyCode: keyCode, direction: direction)

        case .wait:
            break

        case .undo:
            clearMoveHold()
            undo()

        case .redo:
            clearMoveHold()
            redo()

        case .restart:
            clearMoveHold()
            restart()

        case .pause:
            clearMoveHold()
            togglePause()
        }
    }

    private func handleCaveGameplay(_ intent: GameplayIntent, keyCode: UInt16) {
        guard let caveSession else { return }
        switch intent {
        case .move(let direction):
            guard presentationPhase == .playing, caveSession.canAcceptInput else { return }
            caveSession.noteDirectionDown(direction)
            // Kick Tick 1 immediately when leaving Ready.
            advanceCaveSimulation()

        case .wait:
            guard presentationPhase == .playing, caveSession.canAcceptInput else { return }
            caveSession.noteWait()
            advanceCaveSimulation()

        case .restart:
            restartCave()

        case .pause:
            togglePause()

        case .undo, .redo:
            break
        }
        _ = keyCode
    }

    private func handleOutcomeAction() {
        guard presentationPhase == .outcomeAwaitingChoice else { return }
        performFocusedOutcomeAction()
    }

    private func pauseFromShell(alreadyInterrupted: Bool = false) {
        guard let play = activePlay, play.canEnterPauseFromPlaying else { return }
        clearMoveHold()
        play.pause()
        if !alreadyInterrupted {
            audioDirector.interrupt()
        }
        router.enterPaused()
        presentationPhase = .paused
        requestPauseOverlayFocus()
        refreshPublishedState()
    }

    private func requestPauseOverlayFocus() {
        focusedPauseAction = .resume
    }

    private func resumeFromShell() {
        guard let play = activePlay, play.isPaused else { return }
        play.resume()
        audioDirector.resumePlayback()
        router.enterGameplay()
        presentationPhase = .playing
        refreshPublishedState()
    }

    private func resumeIfPaused() {
        guard let play = activePlay, play.isPaused else { return }
        play.resume()
        audioDirector.resumePlayback()
    }

    private func applySessionCommand(_ command: SessionCommand) {
        guard let session else { return }
        gameplayNotice = nil
        let result = session.apply(command)
        applyResults([result])
    }

    private func applyResults(_ results: [SessionApplyResult]) {
        for result in results {
            switch result {
            case .ignored:
                continue

            case .emitted(let emission):
                emissions.apply(emission)
                applyEmissionSideEffects(emission)

            case .faulted(let message):
                clearMoveHold()
                cancelShowOutcome()
                presentationPhase = .faulted
                faultMessage = message
                router.enterModalBlocked()
                scene.discardPendingPresentation()
                audioDirector.reset()
                setActivePlay(nil)
                refreshPublishedState()
                return
            }
        }
        refreshPublishedState()
    }

    private func applyEmissionSideEffects(_ emission: SessionEmission) {
        switch emission.appTransition {
        case .enterOutcomePresenting:
            clearMoveHold()
            if isCaveMode {
                let failed = emission.render.snapshot.status == .failed
                if failed {
                    outcomeTitle = AppStrings.text(.uiOutcomeCaveFailed)
                    outcomePrimaryAction = .playAgain
                    outcomePrimaryTitle = AppStrings.text(.uiOutcomePlayAgain)
                    outcomeHint = AppStrings.text(.uiOutcomeHintCave)
                } else {
                    recordCaveCompletionIfNeeded(snapshot: emission.render.snapshot)
                    configureCaveOutcomeActions(for: currentLevelID)
                }
            } else {
                recordCompletionIfNeeded(snapshot: emission.render.snapshot)
            }
            router.enterOutcomePresenting()
            scheduleShowOutcome()
        case .returnToPlaying:
            clearMoveHold()
            clearCompletionRecordingState()
            cancelShowOutcome()
            presentationPhase = .playing
            router.enterGameplay()
        case nil:
            guard let play = activePlay else { return }
            switch play {
            case .cave:
                if play.phase == .playing || play.phase == .ready {
                    presentationPhase = .playing
                    if router.mode != .gameplay {
                        router.enterGameplay()
                    }
                }
            case .sokoban:
                guard play.phase == .playing else { return }
                // Keep intro until the player dismisses it; restart from intro dismisses first.
                if presentationPhase != .levelIntro {
                    presentationPhase = .playing
                    if router.mode != .gameplay {
                        router.enterGameplay()
                    }
                }
            }
        }
    }

    private func recordCompletionIfNeeded(snapshot: RenderSnapshot) {
        guard !recordedCompletionForSession,
            let descriptor = catalog.descriptor(id: currentLevelID)
        else { return }

        let delta = progressPersistence.recordCompletion(
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            ruleVersion: SokobanRules.ruleVersion,
            moveCount: snapshot.moveCount,
            pushCount: snapshot.pushCount,
            nextLevelID: catalog.descriptor(after: descriptor.id)?.id
        )
        recordedCompletionForSession = true
        outcomeNewBestMoves = delta.newBestMoves
        outcomeNewBestPushes = delta.newBestPushes
        outcomeBestMoveCount = delta.bestMoveCount
        outcomeBestPushCount = delta.bestPushCount
    }

    private func recordCaveCompletionIfNeeded(snapshot: RenderSnapshot) {
        guard !recordedCompletionForSession,
            let descriptor = caveCatalog.descriptor(id: currentLevelID)
        else { return }

        // Cave snapshot: moveCount = remaining ticks, pushCount = score.
        let delta = progressPersistence.recordCaveCompletion(
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            ruleVersion: CaveRules.ruleVersion,
            score: snapshot.pushCount,
            remainingTicks: snapshot.moveCount,
            nextLevelID: caveCatalog.descriptor(after: descriptor.id)?.id
        )
        recordedCompletionForSession = true
        outcomeNewBestMoves = delta.newBestRemainingTicks
        outcomeNewBestPushes = delta.newBestScore
        outcomeBestMoveCount = delta.bestRemainingTicks
        outcomeBestPushCount = delta.bestScore
    }

    private func clearCompletionRecordingState() {
        recordedCompletionForSession = false
        outcomeNewBestMoves = false
        outcomeNewBestPushes = false
        outcomeBestMoveCount = nil
        outcomeBestPushCount = nil
    }

    private func refreshPersistenceDiagnostic() {
        if let reason = runPersistence.disabledReason {
            persistenceDiagnostic = reason
        } else if let reason = progressPersistence.disabledReason {
            persistenceDiagnostic = reason
        } else if let diagnostic = progressPersistence.loadDiagnostic {
            persistenceDiagnostic = diagnostic
        } else {
            persistenceDiagnostic = nil
        }
    }

    private func scheduleShowOutcome() {
        cancelShowOutcome()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.activePlay?.isOutcomePresenting == true else { return }
            guard self.presentationPhase != .outcomeAwaitingChoice else { return }
            self.enterOutcomeAwaitingChoice()
        }
        showOutcomeWorkItem = work
        // Let the win/death jingle breathe; cave WAV is ~1.35s.
        let delay = activePlay?.outcomeOverlayDelay ?? 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelShowOutcome() {
        showOutcomeWorkItem?.cancel()
        showOutcomeWorkItem = nil
    }

    private func enterOutcomeAwaitingChoice() {
        cancelShowOutcome()
        presentationPhase = .outcomeAwaitingChoice
        if router.mode != .outcomePresenting {
            router.enterOutcomePresenting()
        }
        // Open confirm gate; still-held keys stay in pressedKeyCodes so they are
        // not treated as a fresh Return/Space confirm.
        router.releaseOutcomeLocksPreservingPressedKeys()
        if !isCaveMode {
            configureOutcomeActions(for: currentLevelID)
        }
        resetOverlayFocus(for: .outcomeAwaitingChoice)
        refreshPublishedState()
    }

    private func refreshPublishedState() {
        guard let play = activePlay else {
            canUndo = false
            canRedo = false
            canPause = false
            canResume = false
            canRestart = presentationPhase == .runRecovery
            return
        }

        let caps = play.publishedCapabilities(presentationPhase: presentationPhase)
        canUndo = caps.canUndo
        canRedo = caps.canRedo
        canRestart = caps.canRestart
        canPause = caps.canPause
        canResume = caps.canResume

        if let snapshot = scene.currentSnapshot {
            moveCount = snapshot.moveCount
            pushCount = snapshot.pushCount
            completedGoalCount = snapshot.completedGoalCount
            totalGoalCount = snapshot.totalGoalCount
        }
    }
}
