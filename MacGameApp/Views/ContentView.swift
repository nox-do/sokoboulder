import AppKit
import SwiftUI

/// Main play surface: board, HUD, pause / outcome overlays, focus wiring.
struct ContentView: View {
    @StateObject private var controller = SokobanPlayController()
    @State private var overlayKeyMonitor: Any?
    @State private var owningWindowNumber: Int?

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

            VStack(spacing: 0) {
                SokobanHUDView(controller: controller)
                Spacer(minLength: 0)
            }

            switch controller.presentationPhase {
            case .paused:
                SokobanPauseOverlay(controller: controller)
            case .outcomeAnimating:
                VStack {
                    Spacer()
                    SokobanOutcomeAnimatingOverlay(controller: controller)
                }
            case .outcomeAwaitingChoice:
                SokobanOutcomeOverlay(controller: controller)
            case .faulted:
                faultOverlay
            case .playing:
                EmptyView()
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
                Text("Something went wrong")
                    .font(.title.weight(.semibold))
                Text(controller.faultMessage ?? "Unknown fault")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                Button("Reload demo level") {
                    controller.startLevel()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    ContentView()
}
