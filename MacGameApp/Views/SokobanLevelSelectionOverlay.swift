import SwiftUI

/// Modal catalog list that exposes only levels unlocked in campaign progress.
struct SokobanLevelSelectionOverlay: View {
    @ObservedObject var controller: SokobanPlayController
    @FocusState private var focusedID: String?

    private static let backID = "navigation.back"

    private var focusOrder: [String] {
        controller.catalog.levels.compactMap { descriptor in
            controller.levelAvailability(for: descriptor) == .locked ? nil : descriptor.id
        } + [Self.backID]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(AppStrings.text(.uiLevelSelectTitle))
                    .font(.largeTitle.weight(.semibold))

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
                .focused($focusedID, equals: Self.backID)
                .keyboardShortcut(.cancelAction)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
        return Button {
            controller.startSelectedLevel(id: descriptor.id)
        } label: {
            HStack {
                Text(controller.catalog.title(for: descriptor))
                Spacer()
                Text(statusTitle(for: availability))
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(availability == .locked)
        .focused($focusedID, equals: descriptor.id)
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
