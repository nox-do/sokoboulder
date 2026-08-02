import SwiftUI

/// Modal catalog list that exposes only levels unlocked in campaign progress.
struct SokobanLevelSelectionOverlay: View {
    @ObservedObject var controller: SokobanPlayController
    @Environment(\.visualTheme) private var theme
    @FocusState private var focusedID: String?

    private static let backID = "navigation.back"

    private var focusOrder: [String] {
        controller.catalog.levels.compactMap { descriptor in
            controller.levelAvailability(for: descriptor) == .locked ? nil : descriptor.id
        } + [Self.backID]
    }

    var body: some View {
        ZStack {
            theme.ui.overlayScrim.swiftUIColor
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(AppStrings.text(.uiLevelSelectTitle))
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(theme.ui.panelForeground.swiftUIColor)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(controller.catalog.levels, id: \.id) { descriptor in
                            levelButton(for: descriptor)
                        }
                    }
                }
                .frame(maxHeight: 300)

                Button(AppStrings.text(.uiLevelSelectBack)) {
                    controller.returnToLaunchMenu()
                }
                .buttonStyle(.plain)
                .focused($focusedID, equals: Self.backID)
                .themedFocus(isFocused: focusedID == Self.backID, isPrimary: true)
                .keyboardShortcut(.cancelAction)
                .frame(maxWidth: .infinity)
            }
            .padding(32)
            .background(
                theme.ui.panelBackground.swiftUIColor,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .frame(maxWidth: 420)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            focusedID = focusOrder.first
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
        .onExitCommand {
            controller.returnToLaunchMenu()
        }
    }

    private func levelButton(for descriptor: SokobanLevelDescriptor) -> some View {
        let availability = controller.levelAvailability(for: descriptor)
        let enabled = availability != .locked
        return Button {
            controller.startSelectedLevel(id: descriptor.id)
        } label: {
            HStack {
                Text(controller.catalog.title(for: descriptor))
                Spacer()
                Text(statusTitle(for: availability))
                    .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .focused($focusedID, equals: descriptor.id)
        .themedFocus(
            isFocused: focusedID == descriptor.id,
            isEnabled: enabled,
            isPrimary: false
        )
    }

    private func statusTitle(for availability: LevelAvailability) -> String {
        switch availability {
        case .locked:
            AppStrings.text(.uiLevelSelectLocked)
        case .available:
            AppStrings.text(.uiLevelSelectAvailable)
        case .completed:
            AppStrings.text(.uiLevelSelectCompleted)
        }
    }

    private func moveFocus(by offset: Int) {
        focusedID = KeyboardFocusCycle.move(
            from: focusedID,
            in: focusOrder,
            offset: offset
        )
    }

    private func performFocusedAction() {
        guard let focusedID else { return }
        if focusedID == Self.backID {
            controller.returnToLaunchMenu()
        } else {
            controller.startSelectedLevel(id: focusedID)
        }
    }
}
