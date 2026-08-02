import SwiftUI

/// Shared pause overlay driven by ``PausePresentation``.
struct PauseOverlay: View {
    let model: PausePresentation
    let pauseFocusEpoch: UInt64
    let onResume: () -> Void
    let onRestart: () -> Void
    let onSettings: () -> Void
    let onLevelSelection: () -> Void
    let onHelp: () -> Void
    @FocusState private var focusedAction: PauseAction?

    private enum PauseAction: Hashable {
        case resume
        case restart
        case settings
        case levelSelection
        case help
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(model.title)
                    .font(.largeTitle.weight(.semibold))

                Text(model.hint)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Button(model.resumeTitle) {
                        onResume()
                    }
                    .focused($focusedAction, equals: .resume)
                    .keyboardShortcut(.defaultAction)

                    Button(model.restartTitle) {
                        onRestart()
                    }
                    .focused($focusedAction, equals: .restart)

                    Button(model.settingsTitle) {
                        onSettings()
                    }
                    .focused($focusedAction, equals: .settings)

                    Button(model.levelSelectTitle) {
                        onLevelSelection()
                    }
                    .focused($focusedAction, equals: .levelSelection)

                    Button(model.helpTitle) {
                        onHelp()
                    }
                    .focused($focusedAction, equals: .help)
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
        .onChange(of: pauseFocusEpoch) { _, _ in
            focusResumeButton()
        }
    }

    private func focusResumeButton() {
        DispatchQueue.main.async {
            focusedAction = .resume
        }
    }
}
