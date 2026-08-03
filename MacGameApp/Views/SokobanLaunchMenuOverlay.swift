import SwiftUI

/// Campaign entry point shown after a non-fresh boot or completing the campaign.
struct SokobanLaunchMenuOverlay: View {
    @ObservedObject var controller: SokobanPlayController
    @Environment(\.visualTheme) private var theme

    var body: some View {
        ZStack {
            theme.ui.overlayScrim.swiftUIColor
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(AppStrings.text(.uiLaunchTitle))
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(theme.ui.panelForeground.swiftUIColor)

                themedButton(
                    AppStrings.text(.uiLaunchContinue),
                    action: .continueCampaign,
                    primary: true
                ) {
                    controller.continueCampaign()
                }

                themedButton(
                    AppStrings.text(.uiLaunchSelectLevel),
                    action: .selectLevel,
                    primary: false
                ) {
                    controller.openLevelSelection()
                }

                themedButton(AppStrings.text(.uiLaunchHelp), action: .help, primary: false) {
                    controller.openHelpFromLaunchMenu()
                }

                themedButton(AppStrings.text(.uiLaunchSettings), action: .settings, primary: false) {
                    controller.openSettingsFromLaunchMenu()
                }

                themedButton(
                    AppStrings.text(.uiLaunchResetProgress),
                    action: .resetProgress,
                    primary: false
                ) {
                    controller.resetCampaignProgressFromLaunchMenu()
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
        action: LaunchMenuAction,
        primary: Bool,
        _ handler: @escaping () -> Void
    ) -> some View {
        Button(title) {
            controller.setFocusedLaunchAction(action)
            handler()
        }
        .buttonStyle(.plain)
        .themedFocus(
            isFocused: controller.focusedLaunchAction == action,
            isPrimary: primary
        )
        .frame(maxWidth: .infinity)
        .controlSize(.large)
    }
}
