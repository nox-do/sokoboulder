import SwiftUI

/// Short skippable tutorial hint shown before the first move of a fresh level.
struct SokobanLevelIntroOverlay: View {
    @ObservedObject var controller: SokobanPlayController
    @FocusState private var continueFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(controller.levelTitle)
                    .font(.title.weight(.semibold))

                Text(controller.tutorialHintText)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: 360)

                Text(AppStrings.text(.uiIntroSkipHint))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button(AppStrings.text(.uiIntroContinue)) {
                    controller.dismissLevelIntro()
                }
                .focused($continueFocused)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
