import SwiftUI

/// Blocking overlay when a run file cannot be restored.
struct SokobanRunRecoveryOverlay: View {
    @ObservedObject var controller: SokobanPlayController

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(AppStrings.text(.uiRecoveryTitle))
                    .font(.title.weight(.semibold))
                Text(controller.recoveryMessage ?? AppStrings.text(.uiRecoveryFallback))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                Button(AppStrings.text(.uiRecoveryStartFresh)) {
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
