import SwiftUI

/// macOS menu commands routed to the key window's play controller.
///
/// Keyboard equivalents ⌘Z / ⇧⌘Z / ⌘R are also mapped in ``InputMapper`` because
/// the window local key monitor is the reliable gameplay path. These menu items
/// remain for the Edit / Game menus (mouse).
struct SokobanCommands: Commands {
    @FocusedObject private var controller: SokobanPlayController?

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
