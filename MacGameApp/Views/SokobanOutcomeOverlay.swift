import SwiftUI

/// Result overlay shown after the terminal move has visually settled.
///
/// Return/Space confirmation is routed through ``GameplayInputRouter`` only —
/// no `.defaultAction` shortcut, so a skip-Return cannot also confirm. The
/// router confirms whichever button currently has ``FocusState``.
struct SokobanOutcomeOverlay: View {
    @ObservedObject var controller: SokobanPlayController
    @FocusState private var focusedAction: OutcomeFocusedAction?

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(controller.outcomeTitle)
                    .font(.largeTitle.weight(.semibold))

                Text(
                    "\(AppStrings.text(.uiHudMoves)) \(controller.moveCount) · \(AppStrings.text(.uiHudPushes)) \(controller.pushCount) · \(AppStrings.text(.uiHudGoals)) \(controller.completedGoalCount)/\(controller.totalGoalCount)"
                )
                .font(.body.monospacedDigit())

                Text(controller.outcomeHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Button(controller.outcomePrimaryTitle) {
                        controller.performOutcomePrimaryAction()
                    }
                    .focused($focusedAction, equals: .primary)
                    .buttonStyle(.borderedProminent)

                    Button(AppStrings.text(.uiOutcomePlayAgain)) {
                        controller.restartFromOutcomeOverlay()
                    }
                    .focused($focusedAction, equals: .again)
                    .disabled(!controller.canRestart)

                    Button(AppStrings.text(.uiOutcomeUndo)) {
                        controller.undoFromOutcomeOverlay()
                    }
                    .focused($focusedAction, equals: .undo)
                    .disabled(!controller.canUndo)
                }
                .controlSize(.large)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 400)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            focusedAction = .primary
            controller.setFocusedOutcomeAction(.primary)
        }
        .onChange(of: focusedAction) { _, newValue in
            if let newValue {
                controller.setFocusedOutcomeAction(newValue)
            }
        }
    }
}
