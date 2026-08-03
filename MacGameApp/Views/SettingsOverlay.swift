import SwiftUI

/// Shared settings overlay driven by ``SettingsPresentation``.
struct SettingsOverlay: View {
    @Environment(\.visualTheme) private var theme
    let model: SettingsPresentation
    let focusedID: String
    let onFocusChange: (String) -> Void
    let onThemeChange: (String) -> Void
    let onThemeCycle: (Int) -> Void
    let onMusicTrackChange: (AudioGameMode, String) -> Void
    let onMusicTrackCycle: (AudioGameMode, Int) -> Void
    let onReduceMotionChange: (Bool) -> Void
    let onMusicVolumeChange: (Double) -> Void
    let onEffectsVolumeChange: (Double) -> Void
    let onMuteChange: (Bool) -> Void
    let onBack: () -> Void

    private var showsThemePicker: Bool {
        model.themeOptions.count > 1
    }

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

                    if showsThemePicker {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.themeTitle)
                                .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                            Text(AppStrings.text(.uiSettingsThemeHint))
                                .font(.caption)
                                .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)

                            optionChips(
                                options: model.themeOptions.map { ($0.id, $0.title) },
                                selectedID: model.selectedThemeID,
                                focusID: "theme",
                                accessibilityLabel: model.themeTitle,
                                onSelect: onThemeChange
                            )
                        }
                    }

                    ForEach(model.musicTrackGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title)
                                .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                            Text(group.hint)
                                .font(.caption)
                                .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)

                            optionChips(
                                options: group.options.map { ($0.id, $0.title) },
                                selectedID: group.selectedTrackID,
                                focusID: group.id,
                                accessibilityLabel: group.title,
                                onSelect: { onMusicTrackChange(group.game, $0) }
                            )

                            Text(group.creditSummary)
                                .font(.caption)
                                .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)
                            if let notice = group.attributionNotice {
                                Text(notice)
                                    .font(.caption2)
                                    .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)
                            }
                        }
                    }

                    Toggle(
                        isOn: Binding(
                            get: { model.reduceMotionEnabled },
                            set: {
                                onFocusChange("reduceMotion")
                                onReduceMotionChange($0)
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.reduceMotionTitle)
                            Text(model.reduceMotionDetail)
                                .font(.caption)
                                .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)
                        }
                    }
                    .themedFocus(isFocused: focusedID == "reduceMotion", isPrimary: false)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.musicVolumeTitle)
                            .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                        Slider(
                            value: Binding(
                                get: { model.musicVolume },
                                set: {
                                    onFocusChange("music")
                                    onMusicVolumeChange($0)
                                }
                            ),
                            in: 0...1
                        )
                        .tint(theme.ui.focusRing.swiftUIColor)
                    }
                    .themedFocus(isFocused: focusedID == "music", isPrimary: false)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.effectsVolumeTitle)
                            .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                        Slider(
                            value: Binding(
                                get: { model.effectsVolume },
                                set: {
                                    onFocusChange("effects")
                                    onEffectsVolumeChange($0)
                                }
                            ),
                            in: 0...1
                        )
                        .tint(theme.ui.focusRing.swiftUIColor)
                    }
                    .themedFocus(isFocused: focusedID == "effects", isPrimary: false)

                    Toggle(
                        model.muteTitle,
                        isOn: Binding(
                            get: { model.isMuted },
                            set: {
                                onFocusChange("mute")
                                onMuteChange($0)
                            }
                        )
                    )
                    .themedFocus(isFocused: focusedID == "mute", isPrimary: false)

                    Button(model.backTitle) {
                        onFocusChange("back")
                        onBack()
                    }
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
    }

    @ViewBuilder
    private func optionChips(
        options: [(id: String, title: String)],
        selectedID: String,
        focusID: String,
        accessibilityLabel: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.id) { option in
                let selected = option.id == selectedID
                Button {
                    onFocusChange(focusID)
                    onSelect(option.id)
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
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .themedFocus(isFocused: focusedID == focusID, isPrimary: true)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(
            options.first { $0.id == selectedID }?.title ?? selectedID
        )
    }
}

extension SettingsOverlay {
    /// Focus order used by the settings keyboard contract.
    static func keyboardFocusOrder(
        showsThemePicker: Bool,
        musicTrackFocusIDs: [String]
    ) -> [String] {
        var order = ["reduceMotion", "music", "effects", "mute", "back"]
        for focusID in musicTrackFocusIDs.reversed() {
            order.insert(focusID, at: 0)
        }
        if showsThemePicker {
            order.insert("theme", at: 0)
        }
        return order
    }

    static func musicTrackFocusID(for game: AudioGameMode) -> String {
        "musicTrack.\(game.rawValue)"
    }
}
