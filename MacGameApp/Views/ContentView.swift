import AppKit
import SwiftUI

/// Playable Phase-2 spike: SpriteKit board + keyboard routing into ``GameSession``.
struct ContentView: View {
    @StateObject private var controller = SokobanSpikeController()

    var body: some View {
        ZStack {
            SokobanSpriteView(scene: controller.scene) { event in
                controller.handleKeyEvent(event)
            }
            .frame(minWidth: 480, minHeight: 360)
            .accessibilityIdentifier("app.root")

            VStack {
                HStack {
                    Text("SokoBoulder")
                        .font(.headline)
                    Spacer()
                    Text(controller.phaseLabel)
                        .font(.subheadline.monospaced())
                    Text(controller.hudLine)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.ultraThinMaterial)

                Spacer()

                if let banner = controller.banner {
                    Text(banner)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
        ) { _ in
            controller.handleAppDeactivation()
        }
    }
}

#Preview {
    ContentView()
}
