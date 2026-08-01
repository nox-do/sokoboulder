import SwiftUI

/// Result overlay shown after the terminal move has visually settled.
///
/// Return/Space confirmation is routed through ``GameplayInputRouter`` only —
/// no `.defaultAction` shortcut, so a skip-Return cannot also restart.
struct SokobanOutcomeOverlay: View {
    @ObservedObject var controller: SokobanPlayController
    @FocusState private var focusedAction: OutcomeAction?

    private enum OutcomeAction: Hashable {
        case again
        case undo
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Level complete")
                    .font(.largeTitle.weight(.semibold))

                Text(
                    "Moves \(controller.moveCount) · Pushes \(controller.pushCount) · Goals \(controller.completedGoalCount)/\(controller.totalGoalCount)"
                )
                .font(.body.monospacedDigit())

                Text(controller.outcomeHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Button("Play again") {
                        // Pointer / VoiceOver path — keyboard confirm uses the router.
                        controller.restartFromOutcomeOverlay()
                    }
                    .focused($focusedAction, equals: .again)
                    .disabled(!controller.canRestart)

                    Button("Undo last move") {
                        controller.undoFromOutcomeOverlay()
                    }
                    .focused($focusedAction, equals: .undo)
                    .disabled(!controller.canUndo)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 400)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            focusedAction = .again
        }
    }
}
