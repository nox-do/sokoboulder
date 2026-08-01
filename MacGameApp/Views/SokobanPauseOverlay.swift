import SwiftUI

/// Focusable pause overlay. Keyboard Escape still reaches the board via SKView.
struct SokobanPauseOverlay: View {
    @ObservedObject var controller: SokobanPlayController
    @FocusState private var focusedAction: PauseAction?

    private enum PauseAction: Hashable {
        case resume
        case restart
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(AppStrings.text(.uiPauseTitle))
                    .font(.largeTitle.weight(.semibold))

                Text(AppStrings.text(.uiPauseHint))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Button(AppStrings.text(.uiPauseResume)) {
                        controller.resumeFromPauseOverlay()
                    }
                    .focused($focusedAction, equals: .resume)
                    // Primary confirm after Alt-Tab / focus return.
                    .keyboardShortcut(.defaultAction)

                    Button(AppStrings.text(.uiPauseRestart)) {
                        controller.restartFromPauseOverlay()
                    }
                    .focused($focusedAction, equals: .restart)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 360)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .defaultFocus($focusedAction, .resume)
        .onAppear {
            focusResumeButton()
        }
        .onChange(of: controller.pauseFocusEpoch) { _, _ in
            focusResumeButton()
        }
    }

    private func focusResumeButton() {
        // After Alt-Tab the window becomes key asynchronously; defer so
        // FocusState sticks once the app is active again.
        DispatchQueue.main.async {
            focusedAction = .resume
        }
    }
}
