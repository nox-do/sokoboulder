import SwiftUI

private struct SokobanPlayControllerFocusedValueKey: FocusedValueKey {
    typealias Value = SokobanPlayController
}

extension FocusedValues {
    var sokobanPlayController: SokobanPlayController? {
        get { self[SokobanPlayControllerFocusedValueKey.self] }
        set { self[SokobanPlayControllerFocusedValueKey.self] = newValue }
    }
}

/// macOS menu commands routed to the focused window's play controller.
struct SokobanCommands: Commands {
    @FocusedValue(\.sokobanPlayController) private var controller

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                controller?.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!(controller?.canUndo ?? false))

            Button("Redo") {
                controller?.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!(controller?.canRedo ?? false))
        }

        CommandMenu("Game") {
            Button(controller?.canResume == true ? "Resume" : "Pause") {
                controller?.togglePause()
            }
            .disabled(!((controller?.canPause ?? false) || (controller?.canResume ?? false)))

            Divider()

            Button("Restart Level") {
                controller?.restart()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(!(controller?.canRestart ?? false))
        }
    }
}
