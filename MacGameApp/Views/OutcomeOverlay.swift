import SwiftUI

/// Shared result overlay driven by ``OutcomePresentation``.
///
/// Return/Space confirmation is routed through ``GameplayInputRouter`` only —
/// no `.defaultAction` shortcut, so a held completing-move key cannot also confirm.
struct OutcomeOverlay: View {
    @Environment(\.visualTheme) private var theme
    let model: OutcomePresentation
    let focusedAction: OutcomeFocusedAction
    let onFocusChange: (OutcomeFocusedAction) -> Void
    let onPrimary: () -> Void
    let onPlayAgain: () -> Void
    let onUndo: () -> Void
    let onLevelSelection: () -> Void

    var body: some View {
        ZStack {
            theme.ui.overlayScrim.swiftUIColor
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    Text(model.title)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(theme.ui.panelForeground.swiftUIColor)

                    if !model.metrics.isEmpty {
                        Text(
                            model.metrics
                                .map { "\($0.title) \($0.value)" }
                                .joined(separator: " · ")
                        )
                        .font(.body.monospacedDigit())
                        .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                    }

                    if !model.records.isEmpty {
                        VStack(spacing: 4) {
                            ForEach(Array(model.records.enumerated()), id: \.offset) { _, line in
                                HStack(spacing: 8) {
                                    Text("\(line.title): \(line.value)")
                                    if line.isNewRecord {
                                        Text(line.newRecordTitle)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(theme.ui.success.swiftUIColor)
                                    }
                                }
                            }
                        }
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                    }

                    Text(model.hint)
                        .font(.callout)
                        .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 12) {
                        themedButton(
                            model.primaryTitle,
                            action: .primary,
                            enabled: true,
                            primary: true,
                            onPrimary
                        )
                        themedButton(
                            model.playAgainTitle,
                            action: .again,
                            enabled: model.playAgainEnabled,
                            primary: false,
                            onPlayAgain
                        )
                        if model.undoEnabled {
                            themedButton(
                                model.undoTitle,
                                action: .undo,
                                enabled: true,
                                primary: false,
                                onUndo
                            )
                        }
                        themedButton(
                            model.levelSelectTitle,
                            action: .levelSelection,
                            enabled: true,
                            primary: false,
                            onLevelSelection
                        )
                    }
                    .controlSize(.large)
                }
                .padding(32)
            }
            .background(
                theme.ui.panelBackground.swiftUIColor,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .frame(maxWidth: 400)
            .frame(maxHeight: 520)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func themedButton(
        _ title: String,
        action: OutcomeFocusedAction,
        enabled: Bool,
        primary: Bool,
        _ handler: @escaping () -> Void
    ) -> some View {
        Button(title) {
            onFocusChange(action)
            handler()
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .themedFocus(
            isFocused: focusedAction == action,
            isEnabled: enabled,
            isPrimary: primary
        )
        .frame(maxWidth: .infinity)
    }
}
