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
    let themeCatalog: ThemeCatalog
    let settingsStore: AppSettingsStore
    let reduceMotionProvider: ReduceMotionProvider

    private(set) var session: GameSession?

    @Published private(set) var presentationPhase: GamePresentationPhase = .playing
    @Published private(set) var levelTitle = ""
    @Published private(set) var tutorialHintText = ""
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
    /// Launch-menu keyboard selection.
    @Published private(set) var focusedLaunchAction: LaunchMenuAction = .continueCampaign
    /// Pause-menu keyboard selection.
    @Published private(set) var focusedPauseAction: PauseMenuAction = .resume
    /// Level-selection keyboard selection (`navigation.back` or a level id).
    @Published private(set) var focusedLevelSelectionID: String = "navigation.back"
    /// Settings keyboard selection id (`theme`, `mute`, `back`, …).
    @Published private(set) var focusedSettingsID: String = "back"
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

    private(set) var currentLevelID: String

    init(
        audioDirector: AudioDirector = AudioDirector(),
        runPersistence: SokobanRunPersistence,
        progressPersistence: ProgressPersistence,
        catalog: SokobanContentCatalog,
        settingsStore: AppSettingsStore = AppSettingsStore(),
        reduceMotionSource: (any SystemReduceMotionSource)? = nil,
        themeCatalog: ThemeCatalog? = nil
    ) {
        self.audioDirector = audioDirector
        self.scene = SokobanBoardScene(size: CGSize(width: 640, height: 480))
        self.runPersistence = runPersistence
        self.progressPersistence = progressPersistence
        self.catalog = catalog
        self.themeCatalog =
            themeCatalog
            ?? ThemeCatalogLoader.load(
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
        refreshPersistenceDiagnostic()
        bindSettingsSideEffects()
        bootstrapFromPersistence()
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
            self.init(
                audioDirector: audioDirector,
                runPersistence: runPersistence,
                progressPersistence: progressPersistence,
                catalog: catalog,
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
        self.scene = SokobanBoardScene(size: CGSize(width: 640, height: 480))
        self.runPersistence = runPersistence
        self.progressPersistence = progressPersistence
        self.catalog = SokobanContentCatalog(
            campaignID: "",
            levels: [],
            strings: ContentStringTable(values: [:]),
            defaultThemeID: nil,
            defaultAudioThemeID: nil
        )
        self.themeCatalog = ThemeCatalog(
            themes: BuiltInThemes.allFallbacks(),
            defaultThemeID: VisualTheme.standardID
        )
        self.settingsStore = settingsStore
        self.reduceMotionProvider = ReduceMotionProvider(
            settings: settingsStore,
            systemSource: reduceMotionSource ?? WorkspaceReduceMotionSource()
        )
        self.currentLevelID = ""
        self.session = nil
        self.presentationPhase = .faulted
        self.faultMessage = contentLoadFailureMessage
        self.router.enterModalBlocked()
        self.audioDirector.reset()
        bindMoveHoldRepeater()
        bindSettingsSideEffects()
    }

    // MARK: - Presentation models

    var levelIntroPresentation: LevelIntroPresentation {
        LevelIntroPresentation(
            title: levelTitle,
            body: tutorialHintText,
            continueTitle: AppStrings.text(.uiIntroClose),
            skipHint: AppStrings.text(.uiIntroSkipHint)
        )
    }

    var pausePresentation: PausePresentation {
        PausePresentation(
            title: AppStrings.text(.uiPauseTitle),
            hint: AppStrings.text(.uiPauseHint),
            resumeTitle: AppStrings.text(.uiPauseResume),
            restartTitle: AppStrings.text(.uiPauseRestart),
            settingsTitle: AppStrings.text(.uiPauseSettings),
            levelSelectTitle: AppStrings.text(.uiPauseLevelSelect),
            helpTitle: AppStrings.text(.uiPauseHelp)
        )
    }

    var helpPresentation: HelpPresentation {
        HelpPresentation(
            title: AppStrings.text(.uiHelpTitle),
            backTitle: AppStrings.text(.uiHelpBack),
            controls: [
                HelpControlRow(
                    id: "move",
                    title: AppStrings.text(.uiHelpMoveTitle),
                    detail: AppStrings.text(.uiHelpMoveDetail)
                ),
                HelpControlRow(
                    id: "undo_redo",
                    title: AppStrings.text(.uiHelpUndoRedoTitle),
                    detail: AppStrings.text(.uiHelpUndoRedoDetail)
                ),
                HelpControlRow(
                    id: "restart",
                    title: AppStrings.text(.uiHelpRestartTitle),
                    detail: AppStrings.text(.uiHelpRestartDetail)
                ),
                HelpControlRow(
                    id: "pause",
                    title: AppStrings.text(.uiHelpPauseTitle),
                    detail: AppStrings.text(.uiHelpPauseDetail)
                ),
            ],
            tutorialSectionTitle: AppStrings.text(.uiHelpTutorialSection),
            tutorialHints: catalog.levels.compactMap { descriptor in
                guard let hintID = descriptor.tutorialHintID, !hintID.isEmpty else { return nil }
                return HelpTutorialHint(
                    id: hintID,
                    title: catalog.title(for: descriptor),
                    body: catalog.tutorialHint(for: descriptor)
                )
            }
        )
    }

    var settingsPresentation: SettingsPresentation {
        let snap = settingsSnapshot
        return SettingsPresentation(
            title: AppStrings.text(.uiSettingsTitle),
            backTitle: AppStrings.text(.uiSettingsBack),
            themeTitle: AppStrings.text(.uiSettingsTheme),
            themeOptions: themeCatalog.selectableThemes.map {
                SettingsPresentation.ThemeOption(
                    id: $0.id,
                    title: AppStrings.text(id: $0.displayNameID)
                )
            },
            selectedThemeID: visualTheme.id,
            reduceMotionTitle: AppStrings.text(.uiSettingsReduceMotion),
            reduceMotionDetail: AppStrings.text(.uiSettingsReduceMotionDetail),
            reduceMotionEnabled: snap.reduceMotionEnabled,
            musicVolumeTitle: AppStrings.text(.uiSettingsMusicVolume),
            musicVolume: snap.musicVolume,
            effectsVolumeTitle: AppStrings.text(.uiSettingsEffectsVolume),
            effectsVolume: snap.effectsVolume,
            muteTitle: AppStrings.text(.uiSettingsMute),
            isMuted: snap.isMuted
        )
    }

    var outcomePresentation: OutcomePresentation {
        var records: [OutcomeRecordLine] = []
        if let bestMoves = outcomeBestMoveCount {
            records.append(
                OutcomeRecordLine(
                    title: AppStrings.text(.uiOutcomeBestMoves),
                    value: String(bestMoves),
                    isNewRecord: outcomeNewBestMoves,
                    newRecordTitle: AppStrings.text(.uiOutcomeNewRecordMoves)
                )
            )
        }
        if let bestPushes = outcomeBestPushCount {
            records.append(
                OutcomeRecordLine(
                    title: AppStrings.text(.uiOutcomeBestPushes),
                    value: String(bestPushes),
                    isNewRecord: outcomeNewBestPushes,
                    newRecordTitle: AppStrings.text(.uiOutcomeNewRecordPushes)
                )
            )
        }
        return OutcomePresentation(
            title: outcomeTitle,
            metrics: [
                OutcomeMetricLine(
                    id: "moves",
                    title: AppStrings.text(.uiHudMoves),
                    value: String(moveCount)
                ),
                OutcomeMetricLine(
                    id: "pushes",
                    title: AppStrings.text(.uiHudPushes),
                    value: String(pushCount)
                ),
                OutcomeMetricLine(
                    id: "goals",
                    title: AppStrings.text(.uiHudGoals),
                    value: "\(completedGoalCount)/\(totalGoalCount)"
                ),
            ],
            records: records,
            hint: outcomeHint,
            primaryTitle: outcomePrimaryTitle,
            playAgainTitle: AppStrings.text(.uiOutcomePlayAgain),
            playAgainEnabled: canRestart,
            undoTitle: AppStrings.text(.uiOutcomeUndo),
            undoEnabled: canUndo,
            levelSelectTitle: AppStrings.text(.uiOutcomeLevelSelect)
        )
    }

    var boardAccessibilityLabel: String {
        "\(levelTitle), \(AppStrings.text(.uiBoardLabel))"
    }

    var boardAccessibilityValue: String {
        guard let snapshot = scene.currentSnapshot else {
            return AppStrings.text(.uiBoardUnavailable)
        }
        let player = snapshot.player.position
        return "\(AppStrings.text(.uiBoardPlayer)) "
            + "\(AppStrings.text(.uiBoardColumn)) \(player.column + 1), "
            + "\(AppStrings.text(.uiBoardRow)) \(player.row + 1). "
            + "\(AppStrings.text(.uiHudGoals)) "
            + "\(snapshot.completedGoalCount) von \(snapshot.totalGoalCount). "
            + "\(AppStrings.text(.uiHudMoves)) \(snapshot.moveCount), "
            + "\(AppStrings.text(.uiHudPushes)) \(snapshot.pushCount)."
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
        refreshPersistenceDiagnostic()

        let levelID = id ?? currentLevelID
        guard let descriptor = catalog.descriptor(id: levelID) else {
            session = nil
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
            session = nil
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
    func dismissLevelIntro() {
        guard presentationPhase == .levelIntro else { return }
        markCurrentIntroHintSeen()
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

    private func handleMoveHoldKeyUp(_ event: NSEvent) -> Bool {
        guard event.type == .keyUp else { return false }
        guard InputMapper.moveDirection(keyCode: event.keyCode) != nil else { return false }
        moveHoldRepeater.noteKeyUp(keyCode: event.keyCode)
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
        guard let command = OverlayMenuCommandMapper.command(from: event) else {
            return false
        }
        switch presentationPhase {
        case .launchMenu:
            return handleLaunchMenuCommand(command, isRepeat: event.isARepeat)
        case .paused:
            return handlePauseMenuCommand(command, isRepeat: event.isARepeat)
        case .levelSelection:
            return handleLevelSelectionCommand(command, isRepeat: event.isARepeat)
        case .settings:
            return handleSettingsMenuCommand(command, isRepeat: event.isARepeat)
        case .help:
            return handleHelpMenuCommand(command, isRepeat: event.isARepeat)
        case .outcomeAwaitingChoice:
            return handleOutcomeMenuCommand(command, isRepeat: event.isARepeat)
        default:
            return false
        }
    }

    private func handleLaunchMenuCommand(_ command: OverlayMenuCommand, isRepeat: Bool) -> Bool {
        switch command {
        case .moveUp, .moveLeft:
            focusedLaunchAction =
                KeyboardFocusCycle.move(
                    from: focusedLaunchAction,
                    in: LaunchMenuAction.allCases,
                    offset: -1
                ) ?? .continueCampaign
            return true
        case .moveDown, .moveRight:
            focusedLaunchAction =
                KeyboardFocusCycle.move(
                    from: focusedLaunchAction,
                    in: LaunchMenuAction.allCases,
                    offset: 1
                ) ?? .continueCampaign
            return true
        case .activate:
            guard !isRepeat else { return true }
            performFocusedLaunchAction()
            return true
        case .cancel:
            return false
        }
    }

    private func handlePauseMenuCommand(_ command: OverlayMenuCommand, isRepeat: Bool) -> Bool {
        switch command {
        case .moveUp, .moveLeft:
            focusedPauseAction =
                KeyboardFocusCycle.move(
                    from: focusedPauseAction,
                    in: PauseMenuAction.allCases,
                    offset: -1
                ) ?? .resume
            return true
        case .moveDown, .moveRight:
            focusedPauseAction =
                KeyboardFocusCycle.move(
                    from: focusedPauseAction,
                    in: PauseMenuAction.allCases,
                    offset: 1
                ) ?? .resume
            return true
        case .activate:
            guard !isRepeat else { return true }
            performFocusedPauseAction()
            return true
        case .cancel:
            // Escape is already handled by the gameplay router while paused.
            return false
        }
    }

    private func handleLevelSelectionCommand(_ command: OverlayMenuCommand, isRepeat: Bool) -> Bool {
        let order = levelSelectionFocusOrder
        switch command {
        case .moveUp, .moveLeft:
            focusedLevelSelectionID =
                KeyboardFocusCycle.move(
                    from: focusedLevelSelectionID,
                    in: order,
                    offset: -1
                ) ?? order.first ?? Self.levelSelectionBackID
            return true
        case .moveDown, .moveRight:
            focusedLevelSelectionID =
                KeyboardFocusCycle.move(
                    from: focusedLevelSelectionID,
                    in: order,
                    offset: 1
                ) ?? order.first ?? Self.levelSelectionBackID
            return true
        case .activate:
            guard !isRepeat else { return true }
            performFocusedLevelSelectionAction()
            return true
        case .cancel:
            guard !isRepeat else { return true }
            returnToLaunchMenu()
            return true
        }
    }

    private func handleSettingsMenuCommand(_ command: OverlayMenuCommand, isRepeat: Bool) -> Bool {
        let order = settingsFocusOrder
        switch command {
        case .moveUp:
            focusedSettingsID =
                KeyboardFocusCycle.move(from: focusedSettingsID, in: order, offset: -1)
                ?? order.first ?? "back"
            return true
        case .moveDown:
            focusedSettingsID =
                KeyboardFocusCycle.move(from: focusedSettingsID, in: order, offset: 1)
                ?? order.first ?? "back"
            return true
        case .moveLeft:
            if focusedSettingsID == "theme" {
                cycleTheme(by: -1)
            } else {
                focusedSettingsID =
                    KeyboardFocusCycle.move(from: focusedSettingsID, in: order, offset: -1)
                    ?? order.first ?? "back"
            }
            return true
        case .moveRight:
            if focusedSettingsID == "theme" {
                cycleTheme(by: 1)
            } else {
                focusedSettingsID =
                    KeyboardFocusCycle.move(from: focusedSettingsID, in: order, offset: 1)
                    ?? order.first ?? "back"
            }
            return true
        case .activate:
            guard !isRepeat else { return true }
            return performFocusedSettingsAction()
        case .cancel:
            guard !isRepeat else { return true }
            dismissHelpOrSettings()
            return true
        }
    }

    private func handleHelpMenuCommand(_ command: OverlayMenuCommand, isRepeat: Bool) -> Bool {
        switch command {
        case .activate, .cancel:
            guard !isRepeat else { return true }
            dismissHelpOrSettings()
            return true
        case .moveUp, .moveDown, .moveLeft, .moveRight:
            return false
        }
    }

    private func handleOutcomeMenuCommand(_ command: OverlayMenuCommand, isRepeat: Bool) -> Bool {
        switch command {
        case .moveUp, .moveLeft:
            moveOutcomeFocus(by: -1)
            return true
        case .moveDown, .moveRight:
            moveOutcomeFocus(by: 1)
            return true
        case .activate:
            // Return/Space confirm is owned by ``GameplayInputRouter``.
            return false
        case .cancel:
            guard !isRepeat else { return true }
            performOutcomePrimaryAction()
            return true
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

    @discardableResult
    private func performFocusedSettingsAction() -> Bool {
        switch focusedSettingsID {
        case "theme":
            cycleTheme(by: 1)
            return true
        case "reduceMotion":
            updateReduceMotionEnabled(!settingsStore.reduceMotionEnabled)
            return true
        case "mute":
            updateMuted(!settingsStore.isMuted)
            return true
        case "back":
            dismissHelpOrSettings()
            return true
        default:
            return false
        }
    }

    private func moveOutcomeFocus(by offset: Int) {
        let next = KeyboardFocusCycle.move(
            from: focusedOutcomeAction,
            in: outcomeFocusOrder,
            offset: offset
        )
        if let next {
            setFocusedOutcomeAction(next)
        }
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
        catalog.levels.compactMap { descriptor in
            levelAvailability(for: descriptor) == .locked ? nil : descriptor.id
        } + [Self.levelSelectionBackID]
    }

    private var settingsFocusOrder: [String] {
        SettingsOverlay.keyboardFocusOrder(
            showsThemePicker: themeCatalog.selectableThemes.count > 1
        )
    }

    private static let levelSelectionBackID = "navigation.back"

    private func resetOverlayFocus(for phase: GamePresentationPhase) {
        switch phase {
        case .launchMenu:
            focusedLaunchAction = .continueCampaign
        case .paused:
            focusedPauseAction = .resume
        case .levelSelection:
            focusedLevelSelectionID = levelSelectionFocusOrder.first ?? Self.levelSelectionBackID
        case .settings:
            focusedSettingsID = settingsFocusOrder.first ?? "back"
        case .outcomeAwaitingChoice:
            focusedOutcomeAction = .primary
        default:
            break
        }
    }

    func handleAppDeactivation() {
        appIsActive = false
        clearMoveHold()
        router.clearPendingInputs()
        audioDirector.interrupt()
        Task { await runPersistence.flush() }
        guard let session else { return }

        // Only pause when the player is actively playing — not during intro.
        switch (session.phase, presentationPhase) {
        case (.playing, .playing):
            pauseFromShell(alreadyInterrupted: true)
        default:
            break
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
        case .playing, .launchMenu, .levelSelection, .faulted, .runRecovery:
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
        resumeIfPaused()
        clearCompletionRecordingState()
        cancelShowOutcome()
        if presentationPhase == .levelIntro {
            // Restart from intro dismisses without re-showing; hint is marked seen.
            dismissLevelIntro()
        }
        applySessionCommand(.restart)
    }

    func togglePause() {
        guard let session else { return }
        switch presentationPhase {
        case .playing where session.phase == .playing:
            pauseFromShell()
        case .paused:
            resumeFromShell()
        default:
            break
        }
    }

    func resumeFromPauseOverlay() {
        resumeFromShell()
    }

    func restartFromPauseOverlay() {
        restart()
    }

    func openLevelSelectionFromPauseOverlay() {
        guard presentationPhase == .paused else { return }
        teardownSessionForNavigation(phase: .levelSelection)
    }

    func openHelpFromPause() {
        guard presentationPhase == .paused else { return }
        openHelp(returningTo: .paused)
    }

    func openSettingsFromPause() {
        guard presentationPhase == .paused else { return }
        openSettings(returningTo: .paused)
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
            openLaunchMenu()
            return
        }
        overlayReturnOrigin = nil
        switch origin {
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

    func openLaunchMenu() {
        teardownSessionForNavigation(phase: .launchMenu)
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

    /// Wipes run + campaign progress and restarts the first catalog level.
    func resetCampaignProgressFromLaunchMenu() {
        guard presentationPhase == .launchMenu else { return }
        runPersistence.removeRunFile()
        progressPersistence.resetToFresh(firstLevelID: catalog.first.id)
        clearCompletionRecordingState()
        startLevel(id: catalog.first.id, showIntro: true)
    }

    func startSelectedLevel(id: String, showIntro: Bool? = nil) {
        guard progressPersistence.availability(for: id, in: catalog) != .locked else { return }
        progressPersistence.selectLevel(id)
        startLevel(id: id, showIntro: showIntro)
    }

    func levelAvailability(for descriptor: SokobanLevelDescriptor) -> LevelAvailability {
        progressPersistence.availability(for: descriptor.id, in: catalog)
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
            // Variant B: only show intro when the next hint is still unseen.
            startSelectedLevel(id: id)
        case .openLaunchMenu:
            runPersistence.removeRunFile()
            openLaunchMenu()
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
        openLevelSelection()
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
        settingsSnapshot = settingsStore.snapshot
        applyAudioSettingsFromStore()
        applyVisualThemeFromStore()
        scene.prefersReducedMotion = reduceMotionProvider.isReduceMotionEffective

        settingsHandlerID = settingsStore.addChangeHandler { [weak self] in
            guard let self else { return }
            self.settingsSnapshot = self.settingsStore.snapshot
            self.applyAudioSettingsFromStore()
            self.applyVisualThemeFromStore()
        }

        reduceMotionProvider.onEffectiveChange = { [weak self] effective in
            self?.scene.prefersReducedMotion = effective
        }
        // Push the initial effective value through the callback path.
        reduceMotionProvider.refresh()
    }

    private func applyAudioSettingsFromStore() {
        audioDirector.applyOutputSettings(.from(settings: settingsStore.snapshot))
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
        switch runPersistence.load() {
        case .absent:
            if progressPersistence.file.isFreshCampaign {
                startLevel(id: catalog.first.id)
            } else {
                openLaunchMenu()
            }

        case .loaded(let file):
            if progressPersistence.file.isFreshCampaign {
                // Mid-first-tutorial resume: still a fresh campaign, restore directly.
                restoreRun(file)
            } else {
                // Non-fresh campaigns always land on the launch menu; Continue restores.
                openLaunchMenu()
            }

        case .invalid(let message, _):
            enterRunRecovery(message: message)

        case .readFailed(let message):
            // Do not move the file; still allow a fresh start via recovery UI.
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
            if canRestartRunAfterContentChange(file, error: error) {
                // Known tutorial revisions restart in place; a generic content
                // mismatch is only replaced when the run is untouched.
                startLevel(id: file.levelID)
                return
            }
            let message = restoreFailureMessage(error)
            _ = runPersistence.quarantineLoadedInvalidFile(message: message)
            enterRunRecovery(message: message)
        }
    }

    private func canRestartRunAfterContentChange(
        _ file: SokobanRunFileV1,
        error: Error
    ) -> Bool {
        guard let failure = error as? SokobanRunRestoreFailure,
            failure == .contentHashMismatch,
            catalog.descriptor(id: file.levelID) != nil
        else { return false }

        if Self.restartableSupersededTutorialHashes[file.levelID]?
            .contains(file.contentHash) == true
        {
            return true
        }

        return file.commands.isEmpty
            && file.cursor == 0
            && file.checkpoint.moveCount == 0
            && file.checkpoint.pushCount == 0
            && file.checkpoint.status == .playing
    }

    private func bootstrapSession(
        _ newSession: GameSession,
        descriptor: SokobanLevelDescriptor,
        showIntro: Bool
    ) {
        let emission = newSession.start()
        session = newSession
        clearCompletionRecordingState()
        currentLevelID = descriptor.id
        faultMessage = nil
        recoveryMessage = nil
        overlayReturnOrigin = nil
        levelTitle = catalog.title(for: descriptor)
        tutorialHintText = catalog.tutorialHint(for: descriptor)
        configureOutcomeActions(for: descriptor.id)
        scene.apply(emission.render)
        audioDirector.apply(emission.audio)
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
        session = nil
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
        session = nil
        scene.prepareForNewSession()
        audioDirector.reset()
        applyAudioSettingsFromStore()
        presentationPhase = phase
        overlayReturnOrigin = nil
        router.enterModalBlocked()
        resetOverlayFocus(for: phase)
        refreshPublishedState()
    }

    private func restoreFailureMessage(_ error: Error) -> String {
        if let failure = error as? SokobanRunRestoreFailure {
            switch failure {
            case .unknownSchemaVersion(let version):
                return "Run file schema version \(version) is not supported."
            case .unknownCheckpointSchemaVersion(let version):
                return "Checkpoint schema version \(version) is not supported."
            case .unknownLevelID(let id):
                return "Saved level “\(id)” is unknown."
            case .contentHashMismatch:
                return "Saved level content no longer matches this build."
            case .ruleVersionMismatch(let found, let expected):
                return "Rule version \(found) is incompatible (expected \(expected))."
            case .tooManyCommands(let count):
                return "Run file has too many commands (\(count))."
            case .cursorOutOfRange(let cursor, let count):
                return "Run file cursor \(cursor) is outside 0...\(count)."
            case .checkpointInvalid(let detail):
                return "Saved checkpoint is invalid: \(detail)"
            case .commandBlockedDuringReplay(let index):
                return "Saved move \(index) is blocked and cannot be replayed."
            case .commandAfterTerminal(let index):
                return "Saved move \(index) appears after the level already finished."
            case .engineFault(let detail):
                return "Could not restore run: \(detail)"
            }
        }
        return "Could not restore run: \(error.localizedDescription)"
    }

    // MARK: - Private gameplay

    private func handleGameplay(_ intent: GameplayIntent, keyCode: UInt16) {
        switch intent {
        case .move(let direction):
            guard presentationPhase == .playing, let session, session.phase == .playing else {
                return
            }
            moveHoldRepeater.noteKeyDown(keyCode: keyCode, direction: direction)

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

    private func handleOutcomeAction() {
        guard presentationPhase == .outcomeAwaitingChoice else { return }
        performFocusedOutcomeAction()
    }

    private func pauseFromShell(alreadyInterrupted: Bool = false) {
        guard let session, session.phase == .playing else { return }
        clearMoveHold()
        session.pause()
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
        guard let session, session.phase == .paused else { return }
        session.resume()
        audioDirector.resumePlayback()
        router.enterGameplay()
        presentationPhase = .playing
        refreshPublishedState()
    }

    private func resumeIfPaused() {
        guard let session, session.phase == .paused else { return }
        session.resume()
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
                scene.apply(emission.render)
                audioDirector.apply(emission.audio)
                applyEmissionSideEffects(emission)

            case .faulted(let message):
                clearMoveHold()
                cancelShowOutcome()
                presentationPhase = .faulted
                faultMessage = message
                router.enterModalBlocked()
                scene.discardPendingPresentation()
                audioDirector.reset()
                session = nil
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
            recordCompletionIfNeeded(snapshot: emission.render.snapshot)
            router.enterOutcomePresenting()
            scheduleShowOutcome()
        case .returnToPlaying:
            clearMoveHold()
            clearCompletionRecordingState()
            cancelShowOutcome()
            presentationPhase = .playing
            router.enterGameplay()
        case nil:
            guard let session else { return }
            if session.phase == .playing {
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
            guard self.session?.phase == .outcomePresenting else { return }
            guard self.presentationPhase != .outcomeAwaitingChoice else { return }
            self.enterOutcomeAwaitingChoice()
        }
        showOutcomeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
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
        configureOutcomeActions(for: currentLevelID)
        resetOverlayFocus(for: .outcomeAwaitingChoice)
        refreshPublishedState()
    }

    private func refreshPublishedState() {
        guard let session else {
            canUndo = false
            canRedo = false
            canPause = false
            canResume = false
            canRestart = presentationPhase == .runRecovery
            return
        }

        // Help/settings overlays are modal: keep the paused session intact, but
        // do not expose Undo/Redo/Restart (menu shortcuts would resumeIfPaused).
        let sessionCommandsAllowed =
            presentationPhase != .help
            && presentationPhase != .settings

        canUndo =
            sessionCommandsAllowed
            && session.undoCount > 0
            && (session.canAcceptSessionCommand || session.phase == .paused)
        canRedo =
            sessionCommandsAllowed
            && session.redoCount > 0
            && (session.canAcceptSessionCommand || session.phase == .paused)
        canRestart =
            sessionCommandsAllowed
            && (session.phase == .playing
                || session.phase == .paused
                || session.phase == .outcomePresenting)
        canPause = presentationPhase == .playing && session.phase == .playing
        canResume = presentationPhase == .paused

        if let snapshot = scene.currentSnapshot {
            moveCount = snapshot.moveCount
            pushCount = snapshot.pushCount
            completedGoalCount = snapshot.completedGoalCount
            totalGoalCount = snapshot.totalGoalCount
        }
    }
}
