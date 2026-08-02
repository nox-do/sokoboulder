import SwiftUI

private struct VisualThemeKey: EnvironmentKey {
    static let defaultValue = BuiltInThemes.standard
}

extension EnvironmentValues {
    var visualTheme: VisualTheme {
        get { self[VisualThemeKey.self] }
        set { self[VisualThemeKey.self] = newValue }
    }
}

/// Shared focus chrome driven by theme tokens (navigation stays in SwiftUI).
struct ThemedFocusStyle: ViewModifier {
    @Environment(\.visualTheme) private var theme
    let isFocused: Bool
    var isEnabled: Bool = true
    var isPrimary: Bool = true

    func body(content: Content) -> some View {
        let fill =
            !isEnabled
            ? theme.ui.disabledFill.swiftUIColor
            : (isPrimary
                ? theme.ui.primaryFill.swiftUIColor
                : theme.ui.secondaryFill.swiftUIColor)
        let foreground: Color = {
            if !isEnabled {
                return theme.ui.disabledForeground.swiftUIColor
            }
            if isFocused {
                return theme.ui.focusForeground.swiftUIColor
            }
            return isPrimary
                ? theme.ui.primaryForeground.swiftUIColor
                : theme.ui.secondaryForeground.swiftUIColor
        }()

        content
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFocused ? theme.ui.focusBackground.swiftUIColor : fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isFocused ? theme.ui.focusRing.swiftUIColor : Color.clear,
                        lineWidth: isFocused ? 3 : 0
                    )
            )
            .opacity(isEnabled ? 1 : 0.85)
    }
}

extension View {
    func themedFocus(
        isFocused: Bool,
        isEnabled: Bool = true,
        isPrimary: Bool = true
    ) -> some View {
        modifier(
            ThemedFocusStyle(
                isFocused: isFocused,
                isEnabled: isEnabled,
                isPrimary: isPrimary
            )
        )
    }
}
