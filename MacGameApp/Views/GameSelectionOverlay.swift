import SwiftUI

/// Top-level game picker. Höhle is visible but disabled until Phase 4.
struct GameSelectionOverlay: View {
    @ObservedObject var controller: SokobanPlayController
    @Environment(\.visualTheme) private var theme

    var body: some View {
        ZStack {
            theme.ui.overlayScrim.swiftUIColor
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(AppStrings.text(.uiGameSelectTitle))
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(theme.ui.panelForeground.swiftUIColor)

                Text(AppStrings.text(.uiGameSelectSubtitle))
                    .font(.callout)
                    .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)

                themedButton(
                    AppStrings.text(.uiGameSelectSokoban),
                    action: .sokoban,
                    primary: true,
                    enabled: true
                ) {
                    controller.selectSokobanFromGameSelection()
                }

                themedButton(
                    AppStrings.text(.uiGameSelectCave),
                    action: .cave,
                    primary: false,
                    enabled: true,
                    subtitle: AppStrings.text(.uiGameSelectCaveDemoHint)
                ) {
                    controller.selectCaveFromGameSelection()
                }

                themedButton(
                    AppStrings.text(.uiLaunchHelp),
                    action: .help,
                    primary: false,
                    enabled: true
                ) {
                    controller.openHelpFromGameSelection()
                }

                themedButton(
                    AppStrings.text(.uiLaunchSettings),
                    action: .settings,
                    primary: false,
                    enabled: true
                ) {
                    controller.openSettingsFromGameSelection()
                }
            }
            .padding(32)
            .background(
                theme.ui.panelBackground.swiftUIColor,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .frame(maxWidth: 360)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func themedButton(
        _ title: String,
        action: GameSelectionAction,
        primary: Bool,
        enabled: Bool,
        subtitle: String? = nil,
        _ handler: @escaping () -> Void
    ) -> some View {
        Button {
            guard enabled else { return }
            controller.setFocusedGameSelectionAction(action)
            handler()
        } label: {
            VStack(spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .themedFocus(
            isFocused: controller.focusedGameSelectionAction == action,
            isPrimary: primary
        )
        .opacity(enabled ? 1 : 0.45)
        .frame(maxWidth: .infinity)
        .controlSize(.large)
        .accessibilityHint(subtitle ?? "")
    }
}
