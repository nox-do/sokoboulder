import SwiftUI

/// Top HUD for Sokoban: level, counters, goal progress, undo/redo availability.
struct SokobanHUDView: View {
    @ObservedObject var controller: SokobanPlayController

    var body: some View {
        ViewThatFits(in: .horizontal) {
            regularHUD
            compactHUD
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .contain)
    }

    private var regularHUD: some View {
        HStack(spacing: 16) {
            Text(controller.levelTitle)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            labeled(AppStrings.text(.uiHudMoves), value: "\(controller.moveCount)")
            labeled(AppStrings.text(.uiHudPushes), value: "\(controller.pushCount)")
            labeled(
                AppStrings.text(.uiHudGoals),
                value: "\(controller.completedGoalCount)/\(controller.totalGoalCount)"
            )

            HStack(spacing: 8) {
                availability("\(AppStrings.text(.uiHudUndo)) ⌘Z", enabled: controller.canUndo)
                availability("\(AppStrings.text(.uiHudRedo)) ⇧⌘Z", enabled: controller.canRedo)
            }
        }
    }

    private var compactHUD: some View {
        VStack(spacing: 6) {
            Text(controller.levelTitle)
                .font(.headline)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                labeled(AppStrings.text(.uiHudMoves), value: "\(controller.moveCount)")
                labeled(AppStrings.text(.uiHudPushes), value: "\(controller.pushCount)")
                labeled(
                    AppStrings.text(.uiHudGoals),
                    value: "\(controller.completedGoalCount)/\(controller.totalGoalCount)"
                )
                Spacer(minLength: 0)
                availability("⌘Z", enabled: controller.canUndo)
                availability("⇧⌘Z", enabled: controller.canRedo)
            }
        }
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
