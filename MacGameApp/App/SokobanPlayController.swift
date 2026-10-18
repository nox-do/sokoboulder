import AppKit
import GameCore
import SwiftUI

/// Coordinates a game window and the active session.
/// Settings and completion records own their behavior; extensions group UI wiring.
@MainActor
final class SokobanPlayController: ObservableObject {
    let scene: SokobanBoardScene
    let router = GameplayInputRouter()
    let audioDirector: AudioDirector
    let runPersistence: SokobanRunPersistence
    let progressPersistence: ProgressPersistence
    let catalog: SokobanContentCatalog
    let caveCatalog: CaveContentCatalog
    let settings: PlaySettings

    @Published var activePlay: ActivePlaySession?
    let clock: any MonotonicClock = SystemUptimeClock()

    /// Sokoban session when ``activePlay`` is `.sokoban`; otherwise `nil`.
    var session: GameSession? { activePlay?.sokoban }
    /// Cave session when ``activePlay`` is `.cave`; otherwise `nil`.
    var caveSession: CaveSession? { activePlay?.cave }

    @Published var presentationPhase: GamePresentationPhase = .playing
    @Published var levelTitle = ""
    @Published var tutorialHintText = ""
    var isCaveMode: Bool { activePlay?.isCave ?? false }
    /// Which campaign the launch / level-selection menus currently operate on.
    @Published var shellCampaign: ShellCampaign = .sokoban
    @Published var metrics: PlayMetrics = .sokoban(
        SokobanMetrics(moveCount: 0, pushCount: 0, completedGoalCount: 0, totalGoalCount: 0)
    )
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var canPause = false
    @Published var canResume = false
    @Published var canRestart = false
    @Published var faultMessage: String?
    /// Blocking recovery copy when a run file cannot be restored.
    @Published var recoveryMessage: String?
    /// Non-blocking persistence warning; gameplay continues.
    @Published var persistenceDiagnostic: String?
    @Published var gameplayNotice: String?
    @Published var outcome = PlayOutcome()
    @Published var menuFocus = OverlayFocusState()
    /// Where help / settings return when dismissed.
    @Published var overlayReturnOrigin: OverlayReturnOrigin?
    var showOutcomeWorkItem: DispatchWorkItem?
    var appIsActive = true
    let moveHoldRepeater = SokobanMoveHoldRepeater()
    let emissions: EmissionApplicator

    var currentLevelID: String

    init(
        audioDirector: AudioDirector = AudioDirector(),
        runPersistence: SokobanRunPersistence,
        progressPersistence: ProgressPersistence,
        catalog: SokobanContentCatalog,
        caveCatalog: CaveContentCatalog,
        settingsStore: AppSettingsStore = AppSettingsStore(),
        reduceMotionSource: (any SystemReduceMotionSource)? = nil,
        themeCatalog: ThemeCatalog? = nil,
        musicTrackCatalog: MusicTrackCatalog? = nil,
        contentLoadFailureMessage: String? = nil
    ) {
        self.audioDirector = audioDirector
        let boardScene = SokobanBoardScene(size: CGSize(width: 640, height: 480))
        self.scene = boardScene
        self.emissions = EmissionApplicator(scene: boardScene, audioDirector: audioDirector)
        self.runPersistence = runPersistence
        self.progressPersistence = progressPersistence
        self.catalog = catalog
        self.caveCatalog = caveCatalog
        self.settings = PlaySettings(
            store: settingsStore, scene: boardScene, audioDirector: audioDirector,
            reduceMotionSource: reduceMotionSource, themeCatalog: themeCatalog,
            musicTrackCatalog: musicTrackCatalog
        )
        self.currentLevelID = catalog.levels.first?.id ?? ""
        self.runPersistence.onSaveFailure = { [weak self] message in
            self?.persistenceDiagnostic = message
        }
        self.progressPersistence.onSaveFailure = { [weak self] message in
            self?.persistenceDiagnostic = message
        }
        bindMoveHoldRepeater()
        bindSimulationClock()
        refreshPersistenceDiagnostic()
        settings.onChange = { [weak self] in self?.objectWillChange.send() }
        if let contentLoadFailureMessage {
            presentationPhase = .faulted
            faultMessage = contentLoadFailureMessage
            router.enterModalBlocked()
            audioDirector.reset()
        } else {
            bootstrapFromPersistence()
        }
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

    convenience init(
        audioDirector: AudioDirector,
        runPersistence: SokobanRunPersistence,
        progressPersistence: ProgressPersistence,
        contentLoadFailureMessage: String,
        settingsStore: AppSettingsStore = AppSettingsStore(),
        reduceMotionSource: (any SystemReduceMotionSource)? = nil
    ) {
        self.init(
            audioDirector: audioDirector, runPersistence: runPersistence,
            progressPersistence: progressPersistence,
            catalog: SokobanContentCatalog(
                campaignID: "", levels: [], strings: ContentStringTable(values: [:]),
                defaultThemeID: nil, defaultAudioThemeID: nil
            ),
            caveCatalog: CaveContentCatalog(
                campaignID: "", levels: [], strings: ContentStringTable(values: [:])
            ),
            settingsStore: settingsStore, reduceMotionSource: reduceMotionSource,
            themeCatalog: ThemeCatalog(themes: BuiltInThemes.allFallbacks(), defaultThemeID: VisualTheme.standardID),
            musicTrackCatalog: MusicTrackCatalog(
                tracks: BuiltInMusicTracks.allFallbacks(), defaultTrackIDs: BuiltInMusicTracks.defaultTrackIDs()
            ),
            contentLoadFailureMessage: contentLoadFailureMessage
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

    func undo() {
        guard canUndo else { return }
        guard presentationPhase != .help, presentationPhase != .settings else { return }
        resumeFromShell()
        applySessionCommand(.undo)
    }

    func redo() {
        guard canRedo else { return }
        guard presentationPhase != .help, presentationPhase != .settings else { return }
        resumeFromShell()
        applySessionCommand(.redo)
    }

    func restart() {
        guard canRestart else { return }
        guard presentationPhase != .help, presentationPhase != .settings else { return }
        if isCaveMode {
            restartCave()
            return
        }
        resumeFromShell()
        outcome.reset()
        cancelShowOutcome()
        if presentationPhase == .levelIntro {
            // Restart from intro dismisses without re-showing; hint is marked seen.
            dismissLevelIntro()
        }
        applySessionCommand(.restart)
    }

    func restartCave() {
        guard let caveSession else { return }
        clearMoveHold()
        outcome.reset()
        cancelShowOutcome()
        let emission = caveSession.restart()
        emissions.apply(emission)
        enterPlayingPresentation()
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

    func enterPlayingPresentation() {
        presentationPhase = .playing
        router.enterGameplay()
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

    func requestPauseOverlayFocus() {
        menuFocus.pause = .resume
    }

    private func resumeFromShell() {
        guard let play = activePlay, play.isPaused else { return }
        play.resume()
        audioDirector.resumePlayback()
        enterPlayingPresentation()
        refreshPublishedState()
    }

    private func applySessionCommand(_ command: SessionCommand) {
        guard let session else { return }
        gameplayNotice = nil
        let result = session.apply(command)
        applyResult(result)
    }

    func applyResult(_ result: SessionApplyResult) {
        switch result {
        case .ignored:
            break
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
            activePlay = nil
        }
        refreshPublishedState()
    }

    func applyEmissionSideEffects(_ emission: SessionEmission) {
        switch emission.appTransition {
        case .enterOutcomePresenting:
            clearMoveHold()
            if isCaveMode {
                let failed = emission.render.snapshot.status == .failed
                if failed {
                    outcome.failCave()
                } else {
                    outcome.recordCave(
                        snapshot: emission.render.snapshot, levelID: currentLevelID, catalog: caveCatalog,
                        progress: progressPersistence)
                    outcome.configure(game: .cave, nextLevelID: caveCatalog.descriptor(after: currentLevelID)?.id)
                }
            } else {
                outcome.recordSokoban(
                    snapshot: emission.render.snapshot, levelID: currentLevelID, catalog: catalog,
                    progress: progressPersistence)
            }
            router.enterOutcomePresenting()
            scheduleShowOutcome()
        case .returnToPlaying:
            clearMoveHold()
            outcome.reset()
            cancelShowOutcome()
            enterPlayingPresentation()
        case nil:
            guard let play = activePlay else { return }
            guard play.phase == .playing || play.phase == .ready else { return }
            // Keep the level hint until dismissed; ordinary moves preserve held keys.
            guard presentationPhase != .levelIntro else { return }
            presentationPhase = .playing
            if router.mode != .gameplay {
                router.enterGameplay()
            }
        }
    }

    func refreshPublishedState() {
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
            metrics = snapshot.metrics
        }
    }
}
