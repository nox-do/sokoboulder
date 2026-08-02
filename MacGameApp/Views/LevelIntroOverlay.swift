import SwiftUI

/// Shared level-intro overlay driven by ``LevelIntroPresentation``.
struct LevelIntroOverlay: View {
    @Environment(\.visualTheme) private var theme
    let model: LevelIntroPresentation
    let onDismiss: () -> Void
    @FocusState private var continueFocused: Bool

    var body: some View {
        ZStack {
            theme.ui.overlayScrim.swiftUIColor
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(model.title)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(theme.ui.panelForeground.swiftUIColor)

                Text(model.body)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                    .frame(maxWidth: 360)

                Text(model.skipHint)
                    .font(.callout)
                    .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)

                Button(model.continueTitle) {
                    onDismiss()
                }
                .focused($continueFocused)
                .buttonStyle(.plain)
                .themedFocus(isFocused: continueFocused, isPrimary: true)
                .controlSize(.large)
                .accessibilityLabel(AppStrings.text(.uiIntroClose))
            }
            .padding(32)
            .background(
                theme.ui.panelBackground.swiftUIColor,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .frame(maxWidth: 420)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            continueFocused = true
        }
    }
}
