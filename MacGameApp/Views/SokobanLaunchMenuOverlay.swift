import SwiftUI

/// Campaign entry point shown after a non-fresh boot or completing the campaign.
struct SokobanLaunchMenuOverlay: View {
    @ObservedObject var controller: SokobanPlayController
    @Environment(\.visualTheme) private var theme
    @FocusState private var focusedAction: LaunchAction?

    private enum LaunchAction: Hashable, CaseIterable {
        case continueCampaign
        case selectLevel
        case help
        case settings
        case resetProgress
    }

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
        .onAppear {
            focusedAction = .continueCampaign
        }
        .onMoveCommand { direction in
            switch direction {
            case .up, .left:
                focusedAction = KeyboardFocusCycle.move(
                    from: focusedAction,
                    in: LaunchAction.allCases,
                    offset: -1
                )
            case .down, .right:
                focusedAction = KeyboardFocusCycle.move(
                    from: focusedAction,
                    in: LaunchAction.allCases,
                    offset: 1
                )
            @unknown default:
                break
            }
        }
        .onKeyPress(.return) {
            performFocusedAction()
            return .handled
        }
        .onKeyPress(.space) {
            performFocusedAction()
            return .handled
        }
    }

    private func themedButton(
        _ title: String,
        action: LaunchAction,
        primary: Bool,
        _ handler: @escaping () -> Void
    ) -> some View {
        Button(title, action: handler)
            .buttonStyle(.plain)
            .focused($focusedAction, equals: action)
            .themedFocus(isFocused: focusedAction == action, isPrimary: primary)
            .frame(maxWidth: .infinity)
            .controlSize(.large)
    }

    private func performFocusedAction() {
        switch focusedAction ?? .continueCampaign {
        case .continueCampaign:
            controller.continueCampaign()
        case .selectLevel:
            controller.openLevelSelection()
        case .help:
            controller.openHelpFromLaunchMenu()
        case .settings:
            controller.openSettingsFromLaunchMenu()
        case .resetProgress:
            controller.resetCampaignProgressFromLaunchMenu()
        }
    }
}
