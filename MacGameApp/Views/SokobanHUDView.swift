import AppKit
import SwiftUI

/// A compact arcade dashboard using the same sprites and colors as the board.
struct SokobanHUDView: View {
    @ObservedObject var controller: SokobanPlayController
    @Environment(\.visualTheme) private var theme

    private var metricLines: [PlayMetricLine] {
        let lines = PlayMetricsPresentation.lines(metrics: controller.metrics)
        let objectiveID = controller.isCaveMode ? "diamonds" : "goals"
        return lines.filter { $0.id == objectiveID } + lines.filter { $0.id != objectiveID }
    }

    private var objectiveSprite: NSImage? {
        let textures = theme.rendering.textures
        let path = controller.isCaveMode ? textures?.cave?.diamond : textures?.crateOnGoal
        guard let path,
            let url = try? BundleContentResources(bundle: Bundle(for: SokobanPlayController.self)).url(at: path)
        else { return nil }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 24) {
                levelHeading
                Spacer(minLength: 12)
                metrics
                shortcuts
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    levelHeading
                    Spacer(minLength: 8)
                    shortcuts
                }
                metrics
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(theme.ui.hudBackground.swiftUIColor)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.ui.hudForeground.swiftUIColor.opacity(0.12)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                Rectangle().fill(theme.ui.focusRing.swiftUIColor.opacity(0.5)).frame(height: 1)
                Rectangle().fill(Color.black.opacity(0.5)).frame(height: 3)
            }
        }
        .foregroundStyle(theme.ui.hudForeground.swiftUIColor)
        .accessibilityElement(children: .contain)
    }

    private var levelHeading: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(theme.ui.focusRing.swiftUIColor)
                .frame(width: 3, height: 28)
            Text(controller.levelTitle)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        }
    }

    private var metrics: some View {
        HStack(spacing: 18) {
            ForEach(metricLines) { line in
                let isObjective = line.id == "diamonds" || line.id == "goals"
                HStack(spacing: 10) {
                    if isObjective {
                        if let sprite = objectiveSprite {
                            Image(nsImage: sprite)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .accessibilityHidden(true)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(line.title)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(theme.ui.hudSecondary.swiftUIColor)
                        Text(line.value.replacingOccurrences(of: "/", with: " / "))
                            .font(
                                .system(
                                    size: isObjective || line.id == "time" ? 22 : 17,
                                    weight: .bold, design: .monospaced)
                            )
                            .monospacedDigit()
                            .foregroundStyle(
                                isObjective
                                    ? theme.ui.focusRing.swiftUIColor
                                    : theme.ui.hudForeground.swiftUIColor)
                    }
                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(line.title) \(line.value)")
            }
        }
    }

    @ViewBuilder
    private var shortcuts: some View {
        if !controller.isCaveMode {
            HStack(spacing: 6) {
                keycap("⌘Z", title: AppStrings.text(.uiHudUndo), enabled: controller.canUndo)
                keycap("⇧⌘Z", title: AppStrings.text(.uiHudRedo), enabled: controller.canRedo)
            }
        }
    }

    private func keycap(_ key: String, title: String, enabled: Bool) -> some View {
        Text(key)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(theme.ui.secondaryFill.swiftUIColor.opacity(enabled ? 1 : 0.4))
            .overlay {
                Rectangle().strokeBorder(theme.ui.hudSecondary.swiftUIColor.opacity(enabled ? 0.5 : 0.2), lineWidth: 1)
            }
            .foregroundStyle(enabled ? theme.ui.hudForeground.swiftUIColor : theme.ui.disabledForeground.swiftUIColor)
            .help("\(title) \(key)")
            .accessibilityLabel(
                "\(title) \(key) \(enabled ? AppStrings.text(.uiHudAvailable) : AppStrings.text(.uiHudUnavailable))")
    }
}
