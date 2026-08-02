import SwiftUI

/// Shared settings overlay driven by ``SettingsPresentation``.
struct SettingsOverlay: View {
    @Environment(\.visualTheme) private var theme
    let model: SettingsPresentation
    let onThemeChange: (String) -> Void
    let onThemeCycle: (Int) -> Void
    let onReduceMotionChange: (Bool) -> Void
    let onMusicVolumeChange: (Double) -> Void
    let onEffectsVolumeChange: (Double) -> Void
    let onMuteChange: (Bool) -> Void
    let onBack: () -> Void
    @FocusState private var focusedID: String?

    private let focusOrder = SettingsOverlay.keyboardFocusOrder

    var body: some View {
        ZStack {
            theme.ui.overlayScrim.swiftUIColor
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(model.title)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.themeTitle)
                            .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                        Text(AppStrings.text(.uiSettingsThemeHint))
                            .font(.caption)
                            .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)

                        HStack(spacing: 8) {
                            ForEach(model.themeOptions) { option in
                                let selected = option.id == model.selectedThemeID
                                Button {
                                    onThemeChange(option.id)
                                } label: {
                                    Text(option.title)
                                        .font(.body.weight(selected ? .semibold : .regular))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(
                                                    selected
                                                        ? theme.ui.primaryFill.swiftUIColor
                                                        : theme.ui.secondaryFill.swiftUIColor
                                                )
                                        )
                                        .foregroundStyle(
                                            selected
                                                ? theme.ui.primaryForeground.swiftUIColor
                                                : theme.ui.secondaryForeground.swiftUIColor
                                        )
                                }
                                .buttonStyle(.plain)
                                // The row owns keyboard focus; each option remains a direct
                                // mouse and accessibility target without joining the focus cycle.
                                .focusable(false)
                                .accessibilityAddTraits(selected ? .isSelected : [])
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .focusable()
                        .focused($focusedID, equals: "theme")
                        .themedFocus(isFocused: focusedID == "theme", isPrimary: true)
                        .accessibilityLabel(model.themeTitle)
                        .accessibilityValue(
                            model.themeOptions.first { $0.id == model.selectedThemeID }?.title
                                ?? model.selectedThemeID
                        )
                    }

                    Toggle(
                        isOn: Binding(
                            get: { model.reduceMotionEnabled },
                            set: onReduceMotionChange
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.reduceMotionTitle)
                            Text(model.reduceMotionDetail)
                                .font(.caption)
                                .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)
                        }
                    }
                    .focused($focusedID, equals: "reduceMotion")
                    .themedFocus(isFocused: focusedID == "reduceMotion", isPrimary: false)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.musicVolumeTitle)
                            .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                        Slider(
                            value: Binding(
                                get: { model.musicVolume },
                                set: onMusicVolumeChange
                            ),
                            in: 0...1
                        )
                        .focused($focusedID, equals: "music")
                        .tint(theme.ui.focusRing.swiftUIColor)
                    }
                    .themedFocus(isFocused: focusedID == "music", isPrimary: false)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.effectsVolumeTitle)
                            .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                        Slider(
                            value: Binding(
                                get: { model.effectsVolume },
                                set: onEffectsVolumeChange
                            ),
                            in: 0...1
                        )
                        .focused($focusedID, equals: "effects")
                        .tint(theme.ui.focusRing.swiftUIColor)
                    }
                    .themedFocus(isFocused: focusedID == "effects", isPrimary: false)

                    Toggle(
                        model.muteTitle,
                        isOn: Binding(
                            get: { model.isMuted },
                            set: onMuteChange
                        )
                    )
                    .focused($focusedID, equals: "mute")
                    .themedFocus(isFocused: focusedID == "mute", isPrimary: false)

                    Button(model.backTitle) {
                        onBack()
                    }
                    .focused($focusedID, equals: "back")
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .themedFocus(isFocused: focusedID == "back", isPrimary: true)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .padding(32)
            }
            .background(
                theme.ui.panelBackground.swiftUIColor,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(theme.ui.focusBorder.swiftUIColor.opacity(0.35), lineWidth: 1)
            )
            .frame(maxWidth: 420)
            .frame(maxHeight: 520)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            focusedID = "theme"
        }
        .onMoveCommand { direction in
            switch direction {
            case .up:
                moveFocus(by: -1)
            case .down:
                moveFocus(by: 1)
            case .left:
                if focusedID == "theme" {
                    onThemeCycle(-1)
                }
            case .right:
                if focusedID == "theme" {
                    onThemeCycle(1)
                }
            @unknown default:
                break
            }
        }
        .onKeyPress(.return) {
            performFocusedAction()
        }
        .onKeyPress(.space) {
            performFocusedAction()
        }
        .onExitCommand(perform: onBack)
    }

    private func moveFocus(by offset: Int) {
        focusedID = KeyboardFocusCycle.move(
            from: focusedID,
            in: focusOrder,
            offset: offset
        )
    }

    private func performFocusedAction() -> KeyPress.Result {
        switch focusedID {
        case "theme":
            onThemeCycle(1)
            return .handled
        case "reduceMotion":
            onReduceMotionChange(!model.reduceMotionEnabled)
            return .handled
        case "mute":
            onMuteChange(!model.isMuted)
            return .handled
        case "back":
            onBack()
            return .handled
        default:
            return .ignored
        }
    }
}

extension SettingsOverlay {
    /// Focus order used by the settings keyboard contract (theme row is focusable).
    static let keyboardFocusOrder = [
        "theme", "reduceMotion", "music", "effects", "mute", "back",
    ]
}
