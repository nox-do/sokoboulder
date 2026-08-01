import SwiftUI

/// Modal catalog list that exposes only levels unlocked in campaign progress.
struct SokobanLevelSelectionOverlay: View {
    @ObservedObject var controller: SokobanPlayController

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(AppStrings.text(.uiLevelSelectTitle))
                    .font(.largeTitle.weight(.semibold))

                VStack(spacing: 8) {
                    ForEach(controller.catalog.levels, id: \.id) { descriptor in
                        levelButton(for: descriptor)
                    }
                }

                Button(AppStrings.text(.uiLevelSelectBack)) {
                    controller.returnToLaunchMenu()
                }
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 420)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
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
