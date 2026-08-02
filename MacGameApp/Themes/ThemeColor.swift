import AppKit
import Foundation
import SpriteKit
import SwiftUI

/// Parsed theme color token shared by SpriteKit and SwiftUI.
struct ThemeColor: Equatable, Sendable, Hashable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
        self.alpha = Self.clamp(alpha)
    }

    /// Accepts `#RGB`, `#RRGGBB`, or `#RRGGBBAA` (optional leading `#`).
    static func parse(_ string: String) throws -> ThemeColor {
        var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        guard hex.allSatisfy(\.isHexDigit) else {
            throw ThemeDecodeError.invalidColor(string)
        }

        switch hex.count {
        case 3:
            let r = try nibble(hex, 0)
            let g = try nibble(hex, 1)
            let b = try nibble(hex, 2)
            return ThemeColor(red: r, green: g, blue: b)
        case 6:
            return ThemeColor(
                red: try byte(hex, 0),
                green: try byte(hex, 2),
                blue: try byte(hex, 4)
            )
        case 8:
            return ThemeColor(
                red: try byte(hex, 0),
                green: try byte(hex, 2),
                blue: try byte(hex, 4),
                alpha: try byte(hex, 6)
            )
        default:
            throw ThemeDecodeError.invalidColor(string)
        }
    }

    var skColor: SKColor {
        SKColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    var nsColor: NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func nibble(_ hex: String, _ index: Int) throws -> Double {
        let start = hex.index(hex.startIndex, offsetBy: index)
        let digit = hex[start]
        guard let value = Int(String(digit), radix: 16) else {
            throw ThemeDecodeError.invalidColor(hex)
        }
        let expanded = (value << 4) | value
        return Double(expanded) / 255.0
    }

    private static func byte(_ hex: String, _ start: Int) throws -> Double {
        let from = hex.index(hex.startIndex, offsetBy: start)
        let to = hex.index(from, offsetBy: 2)
        guard let value = Int(hex[from..<to], radix: 16) else {
            throw ThemeDecodeError.invalidColor(hex)
        }
        return Double(value) / 255.0
    }
}
