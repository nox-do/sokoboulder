import SwiftUI

/// Campaign entry point shown after a non-fresh boot or completing the campaign.
struct SokobanLaunchMenuOverlay: View {
    @ObservedObject var controller: SokobanPlayController
    @FocusState private var focusedAction: LaunchAction?

    private enum LaunchAction: Hashable {
        case continueCampaign
        case selectLevel
        case help
        case settings
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(AppStrings.text(.uiLaunchTitle))
                    .font(.largeTitle.weight(.semibold))

                Button(AppStrings.text(.uiLaunchContinue)) {
                    controller.continueCampaign()
                }
                .focused($focusedAction, equals: .continueCampaign)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)

                Button(AppStrings.text(.uiLaunchSelectLevel)) {
                    controller.openLevelSelection()
                }
                .focused($focusedAction, equals: .selectLevel)

                Button(AppStrings.text(.uiLaunchHelp)) {
                    controller.openHelpFromLaunchMenu()
                }
                .focused($focusedAction, equals: .help)

                Button(AppStrings.text(.uiLaunchSettings)) {
                    controller.openSettingsFromLaunchMenu()
                }
                .focused($focusedAction, equals: .settings)
            }
            .controlSize(.large)
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 360)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            focusedAction = .continueCampaign
        }
    }
}
