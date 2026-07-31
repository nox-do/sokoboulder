import AppKit
import SpriteKit
import SwiftUI

/// SKView that accepts keyboard focus and forwards key events to the spike controller.
final class KeyHandlingSKView: SKView {
    var onKeyEvent: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        onKeyEvent?(event)
    }

    override func keyUp(with event: NSEvent) {
        onKeyEvent?(event)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

/// Bridges ``SokobanBoardScene`` into SwiftUI.
struct SokobanSpriteView: NSViewRepresentable {
    let scene: SokobanBoardScene
    var onKeyEvent: (NSEvent) -> Void

    func makeNSView(context: Context) -> KeyHandlingSKView {
        let view = KeyHandlingSKView(frame: .zero)
        view.ignoresSiblingOrder = true
        view.allowsTransparency = false
        view.onKeyEvent = onKeyEvent
        view.presentScene(scene)
        return view
    }

    func updateNSView(_ nsView: KeyHandlingSKView, context: Context) {
        nsView.onKeyEvent = onKeyEvent
        if nsView.scene !== scene {
            nsView.presentScene(scene)
        }
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}
