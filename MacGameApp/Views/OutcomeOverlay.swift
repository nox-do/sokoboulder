import SwiftUI

/// Shared result overlay driven by ``OutcomePresentation``.
///
/// Return/Space confirmation is routed through ``GameplayInputRouter`` only —
/// no `.defaultAction` shortcut, so a skip-Return cannot also confirm.
struct OutcomeOverlay: View {
    let model: OutcomePresentation
    let focusedAction: OutcomeFocusedAction
    let onFocusChange: (OutcomeFocusedAction) -> Void
    let onPrimary: () -> Void
    let onPlayAgain: () -> Void
    let onUndo: () -> Void
    let onLevelSelection: () -> Void
    @FocusState private var focusedActionState: OutcomeFocusedAction?

    private var focusOrder: [OutcomeFocusedAction] {
        var actions: [OutcomeFocusedAction] = [.primary]
        if model.playAgainEnabled { actions.append(.again) }
        if model.undoEnabled { actions.append(.undo) }
        actions.append(.levelSelection)
        return actions
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    Text(model.title)
                        .font(.largeTitle.weight(.semibold))

                    if !model.metrics.isEmpty {
                        Text(
                            model.metrics
                                .map { "\($0.title) \($0.value)" }
                                .joined(separator: " · ")
                        )
                        .font(.body.monospacedDigit())
                    }

                    if !model.records.isEmpty {
                        VStack(spacing: 4) {
                            ForEach(Array(model.records.enumerated()), id: \.offset) { _, line in
                                HStack(spacing: 8) {
                                    Text("\(line.title): \(line.value)")
                                    if line.isNewRecord {
                                        Text(line.newRecordTitle)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                        .font(.callout.monospacedDigit())
                    }

                    Text(model.hint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 12) {
                        Button(model.primaryTitle) {
                            onPrimary()
                        }
                        .focused($focusedActionState, equals: .primary)
                        .buttonStyle(.borderedProminent)

                        Button(model.playAgainTitle) {
                            onPlayAgain()
                        }
                        .focused($focusedActionState, equals: .again)
                        .disabled(!model.playAgainEnabled)

                        if model.undoEnabled {
                            Button(model.undoTitle) {
                                onUndo()
                            }
                            .focused($focusedActionState, equals: .undo)
                        }

                        Button(model.levelSelectTitle) {
                            onLevelSelection()
                        }
                        .focused($focusedActionState, equals: .levelSelection)
                    }
                    .controlSize(.large)
                }
                .padding(32)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 400)
            .frame(maxHeight: 520)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            focusedActionState = focusedAction
            onFocusChange(focusedAction)
        }
        .onChange(of: focusedActionState) { _, newValue in
            if let newValue {
                onFocusChange(newValue)
            }
        }
        .onMoveCommand { direction in
            switch direction {
            case .up, .left:
                moveFocus(by: -1)
            case .down, .right:
                moveFocus(by: 1)
            @unknown default:
                break
            }
        }
        .onExitCommand {
            onLevelSelection()
        }
    }

    private func moveFocus(by offset: Int) {
        let next = KeyboardFocusCycle.move(
            from: focusedActionState,
            in: focusOrder,
            offset: offset
        )
        focusedActionState = next
        if let next {
            onFocusChange(next)
        }
    }
}
