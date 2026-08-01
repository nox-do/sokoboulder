import SwiftUI

/// Top HUD for Sokoban: level, counters, goal progress, undo/redo availability.
struct SokobanHUDView: View {
    @ObservedObject var controller: SokobanPlayController

    var body: some View {
        HStack(spacing: 16) {
            Text(controller.levelTitle)
                .font(.headline)

            Spacer()

            labeled(AppStrings.text(.uiHudMoves), value: "\(controller.moveCount)")
            labeled(AppStrings.text(.uiHudPushes), value: "\(controller.pushCount)")
            labeled(
                AppStrings.text(.uiHudGoals),
                value: "\(controller.completedGoalCount)/\(controller.totalGoalCount)"
            )

            HStack(spacing: 8) {
                availability(AppStrings.text(.uiHudUndo), enabled: controller.canUndo)
                availability(AppStrings.text(.uiHudRedo), enabled: controller.canRedo)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .contain)
    }

    private func labeled(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }

    private func availability(_ title: String, enabled: Bool) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(enabled ? Color.primary : Color.secondary)
            .opacity(enabled ? 1 : 0.45)
            .accessibilityLabel(
                "\(title) \(enabled ? AppStrings.text(.uiHudAvailable) : AppStrings.text(.uiHudUnavailable))"
            )
    }
}
