import SwiftUI

/// Shared pause overlay driven by ``PausePresentation``.
struct PauseOverlay: View {
    @Environment(\.visualTheme) private var theme
    let model: PausePresentation
    let focusedAction: PauseMenuAction
    let onFocusChange: (PauseMenuAction) -> Void
    let onResume: () -> Void
    let onRestart: () -> Void
    let onSettings: () -> Void
    let onLevelSelection: () -> Void
    let onHelp: () -> Void

    var body: some View {
        ZStack {
            theme.ui.overlayScrim.swiftUIColor
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(model.title)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(theme.ui.panelForeground.swiftUIColor)

                Text(model.hint)
                    .font(.callout)
                    .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)

                VStack(spacing: 12) {
                    themedButton(model.resumeTitle, action: .resume, primary: true, onResume)
                    themedButton(model.restartTitle, action: .restart, primary: false, onRestart)
                    themedButton(model.settingsTitle, action: .settings, primary: false, onSettings)
                    themedButton(
                        model.levelSelectTitle,
                        action: .levelSelection,
                        primary: false,
                        onLevelSelection
                    )
                    themedButton(model.helpTitle, action: .help, primary: false, onHelp)
                }
            }
            .padding(32)
            .background(
                theme.ui.panelBackground.swiftUIColor,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .frame(maxWidth: 360)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func themedButton(
        _ title: String,
        action: PauseMenuAction,
        primary: Bool,
        _ handler: @escaping () -> Void
    ) -> some View {
        Button(title) {
            onFocusChange(action)
            handler()
        }
        .buttonStyle(.plain)
        .themedFocus(isFocused: focusedAction == action, isPrimary: primary)
        .frame(maxWidth: .infinity)
    }
}
