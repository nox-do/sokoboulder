import SwiftUI

/// Transient banner while the terminal revision is still presenting.
struct SokobanOutcomeAnimatingOverlay: View {
    @ObservedObject var controller: SokobanPlayController
    @Environment(\.visualTheme) private var theme

    var body: some View {
        VStack {
            Spacer()
            Text(AppStrings.text(.uiOutcomeAnimatingTitle))
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
            Text(AppStrings.text(.uiOutcomeAnimatingBody))
                .font(.callout)
                .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)
            Button(AppStrings.text(.uiOutcomeSkip)) {
                controller.skipOutcomePresentation()
            }
            .buttonStyle(.plain)
            .themedFocus(isFocused: true, isPrimary: true)
            .padding(.top, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(theme.ui.hudBackground.swiftUIColor)
    }
}
