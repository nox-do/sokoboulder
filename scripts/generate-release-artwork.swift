#!/usr/bin/env swift
import AppKit

// Regenerate from the repository root: swift scripts/generate-release-artwork.swift
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
func color(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 255) / 255,
        green: CGFloat((hex >> 8) & 255) / 255,
        blue: CGFloat(hex & 255) / 255, alpha: 1)
}
func png(width: Int, height: Int, to path: String, draw: () -> Void) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(path))
}
try png(width: 720, height: 460, to: "scripts/dmg/background.png") {
    color(0xf2f5f9).setFill()
    NSRect(x: 0, y: 0, width: 720, height: 460).fill()
    func text(
        _ value: String, x: CGFloat, top: CGFloat, size: CGFloat,
        weight: NSFont.Weight = .regular, ink: UInt32 = 0x263347
    ) {
        (value as NSString).draw(
            at: NSPoint(x: x, y: 460 - top - size * 1.2),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color(ink),
            ])
    }
    text("SokoBoulder", x: 44, top: 26, size: 32, weight: .bold)
    text("Sokoban & Höhle · macOS", x: 45, top: 70, size: 15, ink: 0x607086)
    for x: CGFloat in [36, 376] {
        NSColor.white.setFill()
        NSBezierPath(
            roundedRect: NSRect(x: x, y: 112, width: 308, height: 228),
            xRadius: 18, yRadius: 18
        ).fill()
    }
    text("Direkt spielen", x: 66, top: 132, size: 20, weight: .semibold)
    text("Doppelklick auf die App", x: 66, top: 161, size: 14, ink: 0x607086)
    text("Installieren", x: 406, top: 132, size: 20, weight: .semibold)
    text("App nach Programme ziehen", x: 406, top: 161, size: 14, ink: 0x607086)
    text("→", x: 344, top: 221, size: 29, weight: .medium, ink: 0x71839c)
    text("Du kannst sofort losspielen.", x: 44, top: 369, size: 17, weight: .semibold)
    text(
        "Zum Behalten: App in „Programme“ ziehen und von dort starten.",
        x: 44, top: 399, size: 14, ink: 0x607086)
}

// Use the game's existing, credited sapphire sprite for a recognisable app icon.
let gem = NSImage(contentsOf: root.appendingPathComponent("MacGameApp/Resources/Textures/cave/diamond.png"))!
let iconDir = "MacGameApp/Resources/Assets.xcassets/AppIcon.appiconset"
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let side = points * scale
        let filename = "icon_\(points)x\(points)@\(scale)x.png"
        try png(width: side, height: side, to: "\(iconDir)/\(filename)") {
            let s = CGFloat(side)
            let tile = NSBezierPath(
                roundedRect: NSRect(
                    x: s * 0.06, y: s * 0.06,
                    width: s * 0.88, height: s * 0.88), xRadius: s * 0.19, yRadius: s * 0.19)
            color(0x17263b).setFill()
            tile.fill()
            NSGraphicsContext.saveGraphicsState()
            tile.addClip()
            NSGraphicsContext.current?.imageInterpolation = .none
            gem.draw(
                in: NSRect(x: s * 0.18, y: s * 0.18, width: s * 0.64, height: s * 0.64),
                from: NSRect(x: 8, y: 8, width: 48, height: 48),
                operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
        }
        images.append([
            "idiom": "mac", "size": "\(points)x\(points)",
            "scale": "\(scale)x", "filename": filename,
        ])
    }
}
let catalog: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys])
    .write(to: root.appendingPathComponent("\(iconDir)/Contents.json"))
