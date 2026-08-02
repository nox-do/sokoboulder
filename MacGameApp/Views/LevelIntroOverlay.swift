import SwiftUI

/// Shared level-intro overlay driven by ``LevelIntroPresentation``.
struct LevelIntroOverlay: View {
    let model: LevelIntroPresentation
    let onDismiss: () -> Void
    @FocusState private var continueFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(model.title)
                    .font(.title.weight(.semibold))

                Text(model.body)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: 360)

                Text(model.skipHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button(model.continueTitle) {
                    onDismiss()
                }
                .focused($continueFocused)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel(AppStrings.text(.uiIntroClose))
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 420)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            continueFocused = true
        }
    }
}
