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
            Button(AppStrings.text(.uiMenuUndo)) {
                controller?.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!(controller?.canUndo ?? false))

            Button(AppStrings.text(.uiMenuRedo)) {
                controller?.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!(controller?.canRedo ?? false))
        }

        CommandMenu(AppStrings.text(.uiMenuGame)) {
            Button(
                controller?.canResume == true
                    ? AppStrings.text(.uiMenuResume)
                    : AppStrings.text(.uiMenuPause)
            ) {
                controller?.togglePause()
            }
            .disabled(!((controller?.canPause ?? false) || (controller?.canResume ?? false)))

            Divider()

            Button(AppStrings.text(.uiMenuRestartLevel)) {
                controller?.restart()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(!(controller?.canRestart ?? false))
        }
    }
}
