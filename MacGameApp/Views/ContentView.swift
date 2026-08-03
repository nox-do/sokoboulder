import AppKit
import SwiftUI

/// Main play surface: board, HUD, pause / outcome overlays, focus wiring.
struct ContentView: View {
    @StateObject private var controller: SokobanPlayController
    @State private var windowKeyMonitor: Any?
    @State private var owningWindowNumber: Int?

    init(
        runPersistence: SokobanRunPersistence,
        progressPersistence: ProgressPersistence,
        catalog: SokobanContentCatalog,
        caveCatalog: CaveContentCatalog,
        settingsStore: AppSettingsStore = AppSettingsStore()
    ) {
        _controller = StateObject(
            wrappedValue: SokobanPlayController(
                runPersistence: runPersistence,
                progressPersistence: progressPersistence,
                catalog: catalog,
                caveCatalog: caveCatalog,
                settingsStore: settingsStore
            )
        )
    }

    init(
        runPersistence: SokobanRunPersistence,
        progressPersistence: ProgressPersistence,
        contentLoadFailureMessage: String,
        settingsStore: AppSettingsStore = AppSettingsStore()
    ) {
        _controller = StateObject(
            wrappedValue: SokobanPlayController(
                audioDirector: AudioDirector(),
                runPersistence: runPersistence,
                progressPersistence: progressPersistence,
                contentLoadFailureMessage: contentLoadFailureMessage,
                settingsStore: settingsStore
            )
        )
    }

    private var boardClaimsKeyboardFocus: Bool {
        controller.presentationPhase == .playing
            && (controller.activePlay?.claimsBoardKeyboardFocus == true)
    }

    private var showsHUD: Bool {
        switch controller.presentationPhase {
        case .gameSelection, .launchMenu, .levelSelection, .help, .settings, .faulted, .runRecovery:
            false
        case .levelIntro, .playing, .paused, .outcomeAwaitingChoice:
            true
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if showsHUD {
                    SokobanHUDView(controller: controller)
                }

                SokobanSpriteView(
                    scene: controller.scene,
                    claimsKeyboardFocus: boardClaimsKeyboardFocus
                ) { event in
                    _ = controller.handleKeyEvent(event)
                } onWindowNumberChange: { windowNumber in
                    owningWindowNumber = windowNumber
                    syncWindowKeyMonitor()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(controller.boardAccessibilityLabel)
                .accessibilityValue(controller.boardAccessibilityValue)
            }
            .accessibilityHidden(controller.presentationPhase != .playing)

            switch controller.presentationPhase {
            case .levelIntro:
                LevelIntroOverlay(model: controller.levelIntroPresentation) {
                    controller.dismissLevelIntro()
                }
            case .paused:
                PauseOverlay(
                    model: controller.pausePresentation,
                    focusedAction: controller.focusedPauseAction,
                    onFocusChange: { controller.setFocusedPauseAction($0) },
                    onResume: { controller.resumeFromPauseOverlay() },
                    onRestart: { controller.restartFromPauseOverlay() },
                    onSettings: { controller.openSettingsFromPause() },
                    onLevelSelection: { controller.openLevelSelectionFromPauseOverlay() },
                    onHelp: { controller.openHelpFromPause() }
                )
            case .help:
                HelpOverlay(model: controller.helpPresentation) {
                    controller.dismissHelpOrSettings()
                }
            case .settings:
                SettingsOverlay(
                    model: controller.settingsPresentation,
                    focusedID: controller.focusedSettingsID,
                    onFocusChange: { controller.setFocusedSettingsID($0) },
                    onThemeChange: { controller.updateThemeID($0) },
                    onThemeCycle: { controller.cycleTheme(by: $0) },
                    onMusicTrackChange: { controller.updateMusicTrackID($1, for: $0) },
                    onMusicTrackCycle: { controller.cycleMusicTrack(for: $0, by: $1) },
                    onReduceMotionChange: { controller.updateReduceMotionEnabled($0) },
                    onMusicVolumeChange: { controller.updateMusicVolume($0) },
                    onEffectsVolumeChange: { controller.updateEffectsVolume($0) },
                    onMuteChange: { controller.updateMuted($0) },
                    onBack: { controller.dismissHelpOrSettings() }
                )
            case .outcomeAwaitingChoice:
                OutcomeOverlay(
                    model: controller.outcomePresentation,
                    focusedAction: controller.focusedOutcomeAction,
                    onFocusChange: { controller.setFocusedOutcomeAction($0) },
                    onPrimary: { controller.performOutcomePrimaryAction() },
                    onPlayAgain: { controller.restartFromOutcomeOverlay() },
                    onUndo: { controller.undoFromOutcomeOverlay() },
                    onLevelSelection: { controller.openLevelSelectionFromOutcome() }
                )
            case .runRecovery:
                SokobanRunRecoveryOverlay(controller: controller)
            case .gameSelection:
                GameSelectionOverlay(controller: controller)
            case .launchMenu:
                SokobanLaunchMenuOverlay(controller: controller)
            case .levelSelection:
                SokobanLevelSelectionOverlay(controller: controller)
            case .faulted:
                faultOverlay
            case .playing:
                EmptyView()
            }

            if let diagnostic = controller.gameplayNotice ?? controller.persistenceDiagnostic,
                controller.presentationPhase != .runRecovery,
                controller.presentationPhase != .faulted
            {
                VStack {
                    Spacer()
                    Text(diagnostic)
                        .font(.caption)
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding()
                }
                .allowsHitTesting(false)
            }
        }
        .frame(minWidth: 520, minHeight: 400)
        .environment(\.visualTheme, controller.visualTheme)
        .accessibilityIdentifier("app.root")
        .focusedValue(\.sokobanPlayController, controller)
        .onAppear { syncWindowKeyMonitor() }
        .onDisappear { removeWindowKeyMonitor() }
        .onChange(of: controller.presentationPhase) { _, _ in
            syncWindowKeyMonitor()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
        ) { _ in
            controller.handleAppDeactivation()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            controller.handleAppActivation()
        }
    }

    /// Routes keys for this window independently of AppKit first-responder changes.
    ///
    /// During gameplay this is the reliable primary path; returning `nil` keeps the
    /// same event from reaching ``KeyHandlingSKView`` a second time. Overlay menu
    /// keys are also owned here via ``SokobanPlayController/handleKeyEvent``.
    private func syncWindowKeyMonitor() {
        removeWindowKeyMonitor()
        guard let owningWindowNumber else { return }

        windowKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) {
            event in
            let eventWindowNumber =
                event.windowNumber == 0
                ? NSApp.keyWindow?.windowNumber
                : event.windowNumber
            guard eventWindowNumber == owningWindowNumber else { return event }
            if controller.handleKeyEvent(event) {
                return nil
            }
            return event
        }
    }

    private func removeWindowKeyMonitor() {
        if let windowKeyMonitor {
            NSEvent.removeMonitor(windowKeyMonitor)
            self.windowKeyMonitor = nil
        }
    }

    private var faultOverlay: some View {
        ZStack {
            controller.visualTheme.ui.overlayScrim.swiftUIColor.ignoresSafeArea()
            VStack(spacing: 16) {
                Text(AppStrings.text(.uiFaultTitle))
                    .font(.title.weight(.semibold))
                    .foregroundStyle(controller.visualTheme.ui.panelForeground.swiftUIColor)
                Text(controller.faultMessage ?? "Unknown fault")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(controller.visualTheme.ui.panelSecondary.swiftUIColor)
                Button(AppStrings.text(.uiFaultReload)) {
                    controller.startLevel(showIntro: true)
                }
                .buttonStyle(.plain)
                .themedFocus(isFocused: true, isPrimary: true)
            }
            .padding(28)
            .background(
                controller.visualTheme.ui.panelBackground.swiftUIColor,
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
    }
}

#Preview {
    let bundle = Bundle(for: SokobanPlayController.self)
    if let catalog = try? BundleContentLoader.loadSokobanCatalog(from: bundle),
        let caveCatalog = try? BundleContentLoader.loadCaveCatalog(from: bundle)
    {
        ContentView(
            runPersistence: SokobanRunPersistence.disabled(reason: "Preview"),
            progressPersistence: ProgressPersistence.disabled(
                reason: "Preview",
                firstLevelID: catalog.first.id
            ),
            catalog: catalog,
            caveCatalog: caveCatalog,
            settingsStore: AppSettingsStore.ephemeral()
        )
    } else {
        ContentView(
            runPersistence: SokobanRunPersistence.disabled(reason: "Preview"),
            progressPersistence: ProgressPersistence.unavailable(reason: "Preview"),
            contentLoadFailureMessage: "Preview content is unavailable.",
            settingsStore: AppSettingsStore.ephemeral()
        )
    }
}
