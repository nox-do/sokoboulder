import SwiftUI

/// Blocking overlay when a run file cannot be restored.
struct SokobanRunRecoveryOverlay: View {
    @ObservedObject var controller: SokobanPlayController
    @Environment(\.visualTheme) private var theme
    @FocusState private var startFocused: Bool

    var body: some View {
        ZStack {
            theme.ui.overlayScrim.swiftUIColor.ignoresSafeArea()
            VStack(spacing: 16) {
                Text(AppStrings.text(.uiRecoveryTitle))
                    .font(.title.weight(.semibold))
                    .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                Text(controller.recoveryMessage ?? AppStrings.text(.uiRecoveryFallback))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)
                    .frame(maxWidth: 360)
                Button(AppStrings.text(.uiRecoveryStartFresh)) {
                    controller.beginFreshRunFromRecovery()
                }
                .buttonStyle(.plain)
                .focused($startFocused)
                .themedFocus(isFocused: startFocused, isPrimary: true)
                .controlSize(.large)
            }
            .padding(28)
            .background(
                theme.ui.panelBackground.swiftUIColor,
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            startFocused = true
        }
    }
}
