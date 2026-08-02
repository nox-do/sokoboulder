import SwiftUI

/// Shared help / controls overview driven by ``HelpPresentation``.
struct HelpOverlay: View {
    let model: HelpPresentation
    let onBack: () -> Void
    @FocusState private var focusedID: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text(model.title)
                    .font(.largeTitle.weight(.semibold))
                    .frame(maxWidth: .infinity)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(AppStrings.text(.uiHelpControlsTitle))
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(model.controls) { row in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.title)
                                        .font(.body.weight(.semibold))
                                    Text(row.detail)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityElement(children: .combine)
                            }
                        }

                        if !model.tutorialHints.isEmpty {
                            Text(model.tutorialSectionTitle)
                                .font(.headline)
                                .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(model.tutorialHints) { hint in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(hint.title)
                                            .font(.body.weight(.semibold))
                                        Text(hint.body)
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityElement(children: .combine)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 280)

                Button(model.backTitle) {
                    onBack()
                }
                .focused($focusedID, equals: "back")
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 480)
            .frame(maxHeight: 360)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            focusedID = "back"
        }
    }
}
