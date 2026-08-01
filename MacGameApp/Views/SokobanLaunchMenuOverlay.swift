import SwiftUI

/// Campaign entry point shown after a non-fresh boot or completing the campaign.
struct SokobanLaunchMenuOverlay: View {
    @ObservedObject var controller: SokobanPlayController

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
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)

                Button(AppStrings.text(.uiLaunchSelectLevel)) {
                    controller.openLevelSelection()
                }
            }
            .controlSize(.large)
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 360)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}
