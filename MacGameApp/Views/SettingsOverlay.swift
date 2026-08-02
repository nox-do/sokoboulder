import SwiftUI

/// Shared settings overlay driven by ``SettingsPresentation``.
struct SettingsOverlay: View {
    let model: SettingsPresentation
    let onReduceMotionChange: (Bool) -> Void
    let onMusicVolumeChange: (Double) -> Void
    let onEffectsVolumeChange: (Double) -> Void
    let onMuteChange: (Bool) -> Void
    let onBack: () -> Void
    @FocusState private var focusedID: String?

    private let focusOrder = ["reduceMotion", "music", "effects", "mute", "back"]

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(model.title)
                        .font(.largeTitle.weight(.semibold))
                        .frame(maxWidth: .infinity)

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
                                .foregroundStyle(.secondary)
                        }
                    }
                    .focused($focusedID, equals: "reduceMotion")

                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.musicVolumeTitle)
                        Slider(
                            value: Binding(
                                get: { model.musicVolume },
                                set: onMusicVolumeChange
                            ),
                            in: 0...1
                        )
                        .focused($focusedID, equals: "music")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.effectsVolumeTitle)
                        Slider(
                            value: Binding(
                                get: { model.effectsVolume },
                                set: onEffectsVolumeChange
                            ),
                            in: 0...1
                        )
                        .focused($focusedID, equals: "effects")
                    }

                    Toggle(
                        model.muteTitle,
                        isOn: Binding(
                            get: { model.isMuted },
                            set: onMuteChange
                        )
                    )
                    .focused($focusedID, equals: "mute")

                    Button(model.backTitle) {
                        onBack()
                    }
                    .focused($focusedID, equals: "back")
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .padding(32)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 420)
            .frame(maxHeight: 520)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            focusedID = "reduceMotion"
        }
        .onMoveCommand { direction in
            switch direction {
            case .up:
                moveFocus(by: -1)
            case .down:
                moveFocus(by: 1)
            case .left, .right:
                break  // Sliders own horizontal adjustment.
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
