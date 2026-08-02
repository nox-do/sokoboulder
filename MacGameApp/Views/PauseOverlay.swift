import SwiftUI

/// Shared pause overlay driven by ``PausePresentation``.
struct PauseOverlay: View {
    @Environment(\.visualTheme) private var theme
    let model: PausePresentation
    let pauseFocusEpoch: UInt64
    let onResume: () -> Void
    let onRestart: () -> Void
    let onSettings: () -> Void
    let onLevelSelection: () -> Void
    let onHelp: () -> Void
    @FocusState private var focusedAction: PauseAction?

    private enum PauseAction: Hashable, CaseIterable {
        case resume
        case restart
        case settings
        case levelSelection
        case help
    }

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
        .defaultFocus($focusedAction, .resume)
        .onAppear {
            focusResumeButton()
        }
        .onChange(of: pauseFocusEpoch) { _, _ in
            focusResumeButton()
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
        .onKeyPress(.return) {
            performFocusedAction()
            return .handled
        }
        .onKeyPress(.space) {
            performFocusedAction()
            return .handled
        }
    }

    private func themedButton(
        _ title: String,
        action: PauseAction,
        primary: Bool,
        _ handler: @escaping () -> Void
    ) -> some View {
        Button(title, action: handler)
            .buttonStyle(.plain)
            .focused($focusedAction, equals: action)
            .themedFocus(isFocused: focusedAction == action, isPrimary: primary)
            .frame(maxWidth: .infinity)
    }

    private func focusResumeButton() {
        DispatchQueue.main.async {
            focusedAction = .resume
        }
    }

    private func moveFocus(by offset: Int) {
        focusedAction = KeyboardFocusCycle.move(
            from: focusedAction,
            in: PauseAction.allCases,
            offset: offset
        )
    }

    private func performFocusedAction() {
        switch focusedAction ?? .resume {
        case .resume: onResume()
        case .restart: onRestart()
        case .settings: onSettings()
        case .levelSelection: onLevelSelection()
        case .help: onHelp()
        }
    }
}
