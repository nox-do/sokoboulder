import AppKit
import SwiftUI

/// Main play surface: board, HUD, pause / outcome overlays, focus wiring.
struct ContentView: View {
    @StateObject private var controller: SokobanPlayController
    @State private var overlayKeyMonitor: Any?
    @State private var owningWindowNumber: Int?

    init(
        runPersistence: SokobanRunPersistence,
        progressPersistence: ProgressPersistence,
        catalog: SokobanContentCatalog
    ) {
        _controller = StateObject(
            wrappedValue: SokobanPlayController(
                runPersistence: runPersistence,
                progressPersistence: progressPersistence,
                catalog: catalog
            )
        )
    }

    init(
        runPersistence: SokobanRunPersistence,
        progressPersistence: ProgressPersistence,
        contentLoadFailureMessage: String
    ) {
        _controller = StateObject(
            wrappedValue: SokobanPlayController(
                audioDirector: AudioDirector(),
                runPersistence: runPersistence,
                progressPersistence: progressPersistence,
                contentLoadFailureMessage: contentLoadFailureMessage
            )
        )
    }

    private var boardClaimsKeyboardFocus: Bool {
        controller.presentationPhase == .playing
    }

    var body: some View {
        ZStack {
            SokobanSpriteView(
                scene: controller.scene,
                claimsKeyboardFocus: boardClaimsKeyboardFocus
            ) { event in
                _ = controller.handleKeyEvent(event)
            } onWindowNumberChange: { windowNumber in
                owningWindowNumber = windowNumber
                syncOverlayKeyMonitor()
            }
            .frame(minWidth: 520, minHeight: 400)
            .accessibilityIdentifier("app.root")

            if controller.presentationPhase != .launchMenu,
               controller.presentationPhase != .levelSelection
            {
                VStack(spacing: 0) {
                    SokobanHUDView(controller: controller)
                    Spacer(minLength: 0)
                }
            }

            switch controller.presentationPhase {
            case .levelIntro:
                SokobanLevelIntroOverlay(controller: controller)
            case .paused:
                SokobanPauseOverlay(controller: controller)
            case .outcomeAnimating:
                VStack {
                    Spacer()
                    SokobanOutcomeAnimatingOverlay(controller: controller)
                }
            case .outcomeAwaitingChoice:
                SokobanOutcomeOverlay(controller: controller)
            case .runRecovery:
                SokobanRunRecoveryOverlay(controller: controller)
            case .launchMenu:
                SokobanLaunchMenuOverlay(controller: controller)
            case .levelSelection:
                SokobanLevelSelectionOverlay(controller: controller)
            case .faulted:
                faultOverlay
            case .playing:
                EmptyView()
            }

            if let diagnostic = controller.persistenceDiagnostic,
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
        .focusedValue(\.sokobanPlayController, controller)
        .onAppear { syncOverlayKeyMonitor() }
        .onDisappear { removeOverlayKeyMonitor() }
        .onChange(of: controller.presentationPhase) { _, _ in
            syncOverlayKeyMonitor()
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

    /// While overlays own first-responder focus, forward keys through the router.
    private func syncOverlayKeyMonitor() {
        removeOverlayKeyMonitor()
        guard !boardClaimsKeyboardFocus else { return }
        guard let owningWindowNumber else { return }

        overlayKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            let eventWindowNumber = event.windowNumber == 0
                ? NSApp.keyWindow?.windowNumber
                : event.windowNumber
            guard eventWindowNumber == owningWindowNumber else { return event }
            if controller.handleKeyEvent(event) {
                return nil
            }
            return event
        }
    }

    private func removeOverlayKeyMonitor() {
        if let overlayKeyMonitor {
            NSEvent.removeMonitor(overlayKeyMonitor)
            self.overlayKeyMonitor = nil
        }
    }

    private var faultOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(AppStrings.text(.uiFaultTitle))
                    .font(.title.weight(.semibold))
                Text(controller.faultMessage ?? "Unknown fault")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                Button(AppStrings.text(.uiFaultReload)) {
                    controller.startLevel(showIntro: true)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    if let catalog = try? BundleContentLoader.loadSokobanCatalog(
        from: Bundle(for: SokobanPlayController.self)
    ) {
        ContentView(
            runPersistence: SokobanRunPersistence.disabled(reason: "Preview"),
            progressPersistence: ProgressPersistence.disabled(
                reason: "Preview",
                firstLevelID: catalog.first.id
            ),
            catalog: catalog
        )
    } else {
        ContentView(
            runPersistence: SokobanRunPersistence.disabled(reason: "Preview"),
            progressPersistence: ProgressPersistence.unavailable(reason: "Preview"),
            contentLoadFailureMessage: "Preview content is unavailable."
        )
    }
}
