import AppKit
import GameCore
import SwiftUI

/// App-layer controller for one Sokoban window: session, input, scene, overlays.
@MainActor
final class SokobanPlayController: ObservableObject {
    static let outcomePresentationTimeout: TimeInterval = 0.45
    /// Intro Variant B: unseen tutorial hints auto-dismiss after this delay.
    static let introAutoDismissDelay: TimeInterval = 5.0

    #if DEBUG
    /// Test override for the outcome settle timeout.
    var outcomePresentationTimeoutForTesting: TimeInterval?
    /// Test override for intro auto-dismiss delay.
    var introAutoDismissDelayForTesting: TimeInterval?
    #endif

    let scene: SokobanBoardScene
    let router = GameplayInputRouter()
    let audioDirector: AudioDirector
    let runPersistence: SokobanRunPersistence
    let progressPersistence: ProgressPersistence
    let catalog: SokobanContentCatalog
    let settingsStore: AppSettingsStore
    let reduceMotionProvider: ReduceMotionProvider
    let assistiveReadingProbe: any AssistiveReadingProbe
    let delayedActionScheduler: any DelayedActionScheduler

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
    /// Bumped when the pause overlay should reclaim keyboard focus (e.g. after Alt-Tab).
    @Published private(set) var pauseFocusEpoch: UInt64 = 0
    /// Where help / settings return when dismissed.
    @Published private(set) var overlayReturnOrigin: OverlayReturnOrigin?
    /// Published mirror so SwiftUI invalidates when the nested settings store changes.
    @Published private(set) var settingsSnapshot: AppSettingsSnapshot = .default

    private var outcomeTimeoutItem: DispatchWorkItem?
    private var outcomeTargetRevision: UInt64?
    private var outcomeGeneration: UInt64 = 0
    private var introAutoDismissToken: (any DelayedActionToken)?
    private var introGeneration: UInt64 = 0
    private var recordedCompletionForSession = false
    private var settingsHandlerID: UUID?
    private var appIsActive = true

    private(set) var currentLevelID: String

    init(
        audioDirector: AudioDirector = AudioDirector(),
        runPersistence: SokobanRunPersistence,
        progressPersistence: ProgressPersistence,
        catalog: SokobanContentCatalog,
        settingsStore: AppSettingsStore = AppSettingsStore(),
        reduceMotionSource: (any SystemReduceMotionSource)? = nil,
        assistiveReadingProbe: any AssistiveReadingProbe = VoiceOverAssistiveReadingProbe(),
        delayedActionScheduler: any DelayedActionScheduler = DispatchDelayedActionScheduler()
    ) {
        self.audioDirector = audioDirector
        self.scene = SokobanBoardScene(size: CGSize(width: 640, height: 480))
        self.runPersistence = runPersistence
        self.progressPersistence = progressPersistence
        self.catalog = catalog
        self.settingsStore = settingsStore
        self.reduceMotionProvider = ReduceMotionProvider(
            settings: settingsStore,
            systemSource: reduceMotionSource ?? WorkspaceReduceMotionSource()
        )
        self.assistiveReadingProbe = assistiveReadingProbe
        self.delayedActionScheduler = delayedActionScheduler
        self.currentLevelID = catalog.first.id
        self.runPersistence.onSaveFailure = { [weak self] message in
            self?.persistenceDiagnostic = message
        }
        self.progressPersistence.onSaveFailure = { [weak self] message in
            self?.persistenceDiagnostic = message
        }
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
        reduceMotionSource: (any SystemReduceMotionSource)? = nil,
        assistiveReadingProbe: any AssistiveReadingProbe = VoiceOverAssistiveReadingProbe(),
        delayedActionScheduler: any DelayedActionScheduler = DispatchDelayedActionScheduler()
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
        self.settingsStore = settingsStore
        self.reduceMotionProvider = ReduceMotionProvider(
            settings: settingsStore,
            systemSource: reduceMotionSource ?? WorkspaceReduceMotionSource()
        )
        self.assistiveReadingProbe = assistiveReadingProbe
        self.delayedActionScheduler = delayedActionScheduler
        self.currentLevelID = ""
        self.session = nil
        self.presentationPhase = .faulted
        self.faultMessage = contentLoadFailureMessage
        self.router.enterModalBlocked()
        self.audioDirector.reset()
        bindSettingsSideEffects()
    }

    // MARK: - Presentation models

    var levelIntroPresentation: LevelIntroPresentation {
        LevelIntroPresentation(
            title: levelTitle,
            body: tutorialHintText,
            continueTitle: AppStrings.text(.uiIntroClose),
            skipHint: AppStrings.text(.uiIntroSkipHint),
            autoDismissDelay: assistiveReadingProbe.preventsIntroAutoDismiss
                ? nil
                : resolvedIntroAutoDismissDelay
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

    private var resolvedIntroAutoDismissDelay: TimeInterval {
        #if DEBUG
        introAutoDismissDelayForTesting ?? Self.introAutoDismissDelay
        #else
        Self.introAutoDismissDelay
        #endif
    }

    // MARK: - Lifecycle

    /// Loads a catalog level without consulting the run file (explicit next / recovery).
    ///
    /// Shows the level intro for an unseen tutorial hint (Variant B). In-session
    /// restart keeps the existing session and does not call this path.
    func startLevel(id: String? = nil, showIntro: Bool? = nil) {
        cancelOutcomeWait()
        cancelIntroAutoDismiss()
        audioDirector.reset()
        applyAudioSettingsFromStore()
        scene.prepareForNewSession()
        recoveryMessage = nil
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
        cancelIntroAutoDismiss()
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
        switch router.routeDecision(event) {
        case .unhandled:
            return false
        case .consumed:
            return true
        case .routed(let routed):
            switch routed {
            case .gameplay(let intent):
                handleGameplay(intent)
            case .outcomeAction:
                handleOutcomeAction()
            case .dismissIntro:
                dismissLevelIntro()
            }
            return true
        }
    }

    func handleAppDeactivation() {
        appIsActive = false
        if presentationPhase == .levelIntro {
            cancelIntroAutoDismiss()
        }
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
        case .outcomeAnimating, .outcomeAwaitingChoice:
            audioDirector.resumePlayback()
        case .levelIntro:
            audioDirector.resumePlayback()
            scheduleIntroAutoDismissIfNeeded()
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
        if presentationPhase == .outcomeAnimating || presentationPhase == .outcomeAwaitingChoice {
            cancelOutcomeWait()
        }
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
        refreshPublishedState()
    }

    func continueCampaign() {
        switch runPersistence.load() {
        case .loaded(let file):
            restoreRun(file)
        case .absent:
            let levelID = progressPersistence.file.lastSelectedLevelID
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

    /// Keeps router confirm and overlay Tab-focus aligned.
    func setFocusedOutcomeAction(_ action: OutcomeFocusedAction) {
        if action == .undo, !canUndo {
            focusedOutcomeAction = .primary
            return
        }
        focusedOutcomeAction = action
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

    /// Skips remaining terminal presentation and opens the result overlay.
    func skipOutcomePresentation() {
        guard presentationPhase == .outcomeAnimating else { return }
        scene.discardPendingPresentation()
        enterOutcomeAwaitingChoice()
    }

    // MARK: - Private bootstrap

    private func bindSettingsSideEffects() {
        settingsSnapshot = settingsStore.snapshot
        applyAudioSettingsFromStore()
        scene.prefersReducedMotion = reduceMotionProvider.isReduceMotionEffective

        settingsHandlerID = settingsStore.addChangeHandler { [weak self] in
            guard let self else { return }
            self.settingsSnapshot = self.settingsStore.snapshot
            self.applyAudioSettingsFromStore()
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
            guard let descriptor = catalog.descriptor(id: restored.levelID) else {
                enterRunRecovery(message: "Saved level is no longer in the catalog.")
                return
            }
            cancelOutcomeWait()
            cancelIntroAutoDismiss()
            audioDirector.reset()
            applyAudioSettingsFromStore()
            scene.prepareForNewSession()
            // Mid-run restore skips the intro; the player already knows the level.
            bootstrapSession(newSession, descriptor: descriptor, showIntro: false)
        } catch {
            let message = restoreFailureMessage(error)
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
        presentationPhase = .levelIntro
        router.enterLevelIntro()
        scheduleIntroAutoDismissIfNeeded()
    }

    private func scheduleIntroAutoDismissIfNeeded() {
        cancelIntroAutoDismiss(clearGeneration: false)
        guard appIsActive else { return }
        guard !assistiveReadingProbe.preventsIntroAutoDismiss else { return }
        introGeneration &+= 1
        let generation = introGeneration
        let delay = resolvedIntroAutoDismissDelay
        introAutoDismissToken = delayedActionScheduler.schedule(after: delay) { [weak self] in
            guard let self else { return }
            guard generation == self.introGeneration else { return }
            guard self.presentationPhase == .levelIntro else { return }
            guard !self.assistiveReadingProbe.preventsIntroAutoDismiss else {
                self.introAutoDismissToken = nil
                return
            }
            self.dismissLevelIntro()
        }
    }

    private func cancelIntroAutoDismiss(clearGeneration: Bool = true) {
        introAutoDismissToken?.cancel()
        introAutoDismissToken = nil
        if clearGeneration {
            introGeneration &+= 1
        }
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
        cancelOutcomeWait()
        cancelIntroAutoDismiss()
        session = nil
        scene.prepareForNewSession()
        audioDirector.reset()
        applyAudioSettingsFromStore()
        presentationPhase = phase
        overlayReturnOrigin = nil
        router.enterModalBlocked()
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

    private func handleGameplay(_ intent: GameplayIntent) {
        switch intent {
        case .move(let direction):
            guard presentationPhase == .playing, let session, session.phase == .playing else { return }
            applyResults(session.submitMove(direction))

        case .undo:
            undo()

        case .redo:
            redo()

        case .restart:
            restart()

        case .pause:
            togglePause()
        }
    }

    private func handleOutcomeAction() {
        switch presentationPhase {
        case .outcomeAnimating:
            skipOutcomePresentation()
        case .outcomeAwaitingChoice:
            performFocusedOutcomeAction()
        default:
            break
        }
    }

    private func pauseFromShell(alreadyInterrupted: Bool = false) {
        guard let session, session.phase == .playing else { return }
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
        pauseFocusEpoch &+= 1
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
                cancelOutcomeWait()
                cancelIntroAutoDismiss()
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
            recordCompletionIfNeeded(snapshot: emission.render.snapshot)
            beginOutcomeAnimating(targetRevision: emission.render.targetRevision)
        case .returnToPlaying:
            clearCompletionRecordingState()
            cancelOutcomeWait()
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

    private func beginOutcomeAnimating(targetRevision: UInt64) {
        cancelOutcomeWait()
        presentationPhase = .outcomeAnimating
        router.enterOutcomePresenting()
        outcomeTargetRevision = targetRevision
        outcomeGeneration &+= 1
        let generation = outcomeGeneration

        scene.whenSettled(revision: targetRevision) { [weak self] in
            guard let self else { return }
            guard generation == self.outcomeGeneration else { return }
            guard self.presentationPhase == .outcomeAnimating else { return }
            self.enterOutcomeAwaitingChoice()
        }

        let timeout = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard generation == self.outcomeGeneration else { return }
            guard self.presentationPhase == .outcomeAnimating else { return }
            self.scene.discardPendingPresentation()
            self.enterOutcomeAwaitingChoice()
        }
        outcomeTimeoutItem = timeout
        let delay: TimeInterval
        #if DEBUG
        delay = outcomePresentationTimeoutForTesting ?? Self.outcomePresentationTimeout
        #else
        delay = Self.outcomePresentationTimeout
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: timeout)
    }

    private func enterOutcomeAwaitingChoice() {
        cancelOutcomeWait(clearGeneration: false)
        presentationPhase = .outcomeAwaitingChoice
        if router.mode != .outcomePresenting {
            router.enterOutcomePresenting()
        }
        router.releaseOutcomeLocksPreservingPressedKeys()
        focusedOutcomeAction = .primary
        configureOutcomeActions(for: currentLevelID)
        refreshPublishedState()
    }

    private func cancelOutcomeWait(clearGeneration: Bool = true) {
        outcomeTimeoutItem?.cancel()
        outcomeTimeoutItem = nil
        outcomeTargetRevision = nil
        if clearGeneration {
            outcomeGeneration &+= 1
        }
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
        let sessionCommandsAllowed = presentationPhase != .help
            && presentationPhase != .settings

        canUndo = sessionCommandsAllowed
            && session.undoCount > 0
            && (session.canAcceptSessionCommand || session.phase == .paused)
        canRedo = sessionCommandsAllowed
            && session.redoCount > 0
            && (session.canAcceptSessionCommand || session.phase == .paused)
        canRestart = sessionCommandsAllowed
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
