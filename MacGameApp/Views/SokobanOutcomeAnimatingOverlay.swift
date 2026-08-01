import SwiftUI

/// Transient banner while the terminal revision is still presenting.
struct SokobanOutcomeAnimatingOverlay: View {
    @ObservedObject var controller: SokobanPlayController

    var body: some View {
        VStack {
            Spacer()
            Text(AppStrings.text(.uiOutcomeAnimatingTitle))
                .font(.title2.weight(.semibold))
            Text(AppStrings.text(.uiOutcomeAnimatingBody))
                .font(.callout)
                .foregroundStyle(.secondary)
            Button(AppStrings.text(.uiOutcomeSkip)) {
                controller.skipOutcomePresentation()
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}
