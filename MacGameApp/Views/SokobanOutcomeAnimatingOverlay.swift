import SwiftUI

/// Transient banner while the terminal revision is still presenting.
struct SokobanOutcomeAnimatingOverlay: View {
    @ObservedObject var controller: SokobanPlayController

    var body: some View {
        VStack {
            Spacer()
            Text("Level complete")
                .font(.title2.weight(.semibold))
            Text("Finishing move… Return skips")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Skip") {
                controller.skipOutcomePresentation()
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}
