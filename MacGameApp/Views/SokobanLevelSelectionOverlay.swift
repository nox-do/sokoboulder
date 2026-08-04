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

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(controller.levelSelectionRows) { row in
                                levelButton(for: row)
                                    .id(row.id)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    // `minHeight: 0` forces the scroll view to accept a bounded
                    // height on macOS instead of expanding to its ideal content size.
                    .frame(minHeight: 0, maxHeight: 360)
                    .scrollIndicators(.visible)
                    .onChange(of: controller.focusedLevelSelectionID) { _, focusedID in
                        guard focusedID != Self.backID else { return }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(focusedID, anchor: .center)
                        }
                    }
                }

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
                .id(Self.backID)
            }
            .padding(32)
            .background(
                theme.ui.panelBackground.swiftUIColor,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .frame(maxWidth: 420)
            .frame(maxHeight: 520)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func levelButton(for row: LevelSelectionRow) -> some View {
        let enabled = row.availability != .locked
        return Button {
            controller.setFocusedLevelSelectionID(row.id)
            controller.startSelectedLevel(id: row.id)
        } label: {
            HStack {
                Text(row.title)
                Spacer()
                Text(statusTitle(for: row.availability))
                    .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .themedFocus(
            isFocused: controller.focusedLevelSelectionID == row.id,
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
