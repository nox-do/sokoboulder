import SwiftUI

/// Blocking overlay when a run file cannot be restored.
struct SokobanRunRecoveryOverlay: View {
    @ObservedObject var controller: SokobanPlayController

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Cannot resume")
                    .font(.title.weight(.semibold))
                Text(controller.recoveryMessage ?? "The saved run is not usable.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                Button("Start fresh") {
                    controller.beginFreshRunFromRecovery()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}
