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
                Text("Paused")
                    .font(.largeTitle.weight(.semibold))

                Text("Escape resumes · gameplay input is blocked")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Button("Resume") {
                        controller.resumeFromPauseOverlay()
                    }
                    .focused($focusedAction, equals: .resume)

                    Button("Restart") {
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
        .onAppear {
            focusedAction = .resume
        }
    }
}
