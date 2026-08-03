import SwiftUI

/// Modal catalog list that exposes only levels unlocked in campaign progress.
struct SokobanLevelSelectionOverlay: View {
    @ObservedObject var controller: SokobanPlayController
    @Environment(\.visualTheme) private var theme

    private static let backID = "navigation.back"

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
                    controller.setFocusedLevelSelectionID(Self.backID)
                    controller.returnToLaunchMenu()
                }
                .buttonStyle(.plain)
                .themedFocus(
                    isFocused: controller.focusedLevelSelectionID == Self.backID,
                    isPrimary: true
                )
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
    }

    private func levelButton(for descriptor: SokobanLevelDescriptor) -> some View {
        let availability = controller.levelAvailability(for: descriptor)
        let enabled = availability != .locked
        return Button {
            controller.setFocusedLevelSelectionID(descriptor.id)
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
        .themedFocus(
            isFocused: controller.focusedLevelSelectionID == descriptor.id,
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
}
