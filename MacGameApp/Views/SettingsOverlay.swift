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

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text(model.title)
                    .font(.largeTitle.weight(.semibold))
                    .frame(maxWidth: .infinity)

                Toggle(isOn: Binding(
                    get: { model.reduceMotionEnabled },
                    set: onReduceMotionChange
                )) {
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

                Toggle(model.muteTitle, isOn: Binding(
                    get: { model.isMuted },
                    set: onMuteChange
                ))
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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 420)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            focusedID = "reduceMotion"
        }
    }
}
