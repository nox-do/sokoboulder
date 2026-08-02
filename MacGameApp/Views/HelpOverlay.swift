import SwiftUI

/// Shared help / controls overview driven by ``HelpPresentation``.
struct HelpOverlay: View {
    @Environment(\.visualTheme) private var theme
    let model: HelpPresentation
    let onBack: () -> Void
    @FocusState private var focusedID: String?

    var body: some View {
        ZStack {
            theme.ui.overlayScrim.swiftUIColor
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text(model.title)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                    .frame(maxWidth: .infinity)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(AppStrings.text(.uiHelpControlsTitle))
                            .font(.headline)
                            .foregroundStyle(theme.ui.panelForeground.swiftUIColor)

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(model.controls) { row in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                                    Text(row.detail)
                                        .font(.callout)
                                        .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityElement(children: .combine)
                            }
                        }

                        if !model.tutorialHints.isEmpty {
                            Text(model.tutorialSectionTitle)
                                .font(.headline)
                                .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                                .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(model.tutorialHints) { hint in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(hint.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(theme.ui.panelForeground.swiftUIColor)
                                        Text(hint.body)
                                            .font(.callout)
                                            .foregroundStyle(theme.ui.panelSecondary.swiftUIColor)
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
                .buttonStyle(.plain)
                .themedFocus(isFocused: focusedID == "back", isPrimary: true)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
            .padding(32)
            .background(
                theme.ui.panelBackground.swiftUIColor,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .frame(maxWidth: 480)
            .frame(maxHeight: 360)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            focusedID = "back"
        }
        .onKeyPress(.return) {
            onBack()
            return .handled
        }
        .onKeyPress(.space) {
            onBack()
            return .handled
        }
        .onExitCommand(perform: onBack)
    }
}
