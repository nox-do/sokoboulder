import AppKit
import SpriteKit
import SwiftUI

/// SKView that can optionally accept keyboard focus and forward key events.
final class KeyHandlingSKView: SKView {
    var onKeyEvent: ((NSEvent) -> Void)?
    var onWindowNumberChange: ((Int?) -> Void)?
    /// When false, the view refuses first-responder status so overlays keep focus.
    var claimsKeyboardFocus = true

    override var acceptsFirstResponder: Bool { claimsKeyboardFocus }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowNumberChange?(window?.windowNumber)
        claimFocusIfNeeded()
    }

    override func keyDown(with event: NSEvent) {
        onKeyEvent?(event)
    }

    override func keyUp(with event: NSEvent) {
        onKeyEvent?(event)
    }

    override func mouseDown(with event: NSEvent) {
        if claimsKeyboardFocus {
            window?.makeFirstResponder(self)
        }
        super.mouseDown(with: event)
    }

    func claimFocusIfNeeded() {
        guard claimsKeyboardFocus else { return }
        window?.makeFirstResponder(self)
    }
}

/// Bridges ``SokobanBoardScene`` into SwiftUI.
struct SokobanSpriteView: NSViewRepresentable {
    let scene: SokobanBoardScene
    /// Only claim first responder while gameplay should own the keyboard.
    var claimsKeyboardFocus: Bool
    var onKeyEvent: (NSEvent) -> Void
    var onWindowNumberChange: (Int?) -> Void

    final class Coordinator {
        var wasClaimingFocus = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> KeyHandlingSKView {
        let view = KeyHandlingSKView(frame: .zero)
        view.ignoresSiblingOrder = true
        view.allowsTransparency = false
        view.claimsKeyboardFocus = claimsKeyboardFocus
        view.onKeyEvent = onKeyEvent
        view.onWindowNumberChange = onWindowNumberChange
        view.presentScene(scene)
        context.coordinator.wasClaimingFocus = claimsKeyboardFocus
        if claimsKeyboardFocus {
            DispatchQueue.main.async {
                view.claimFocusIfNeeded()
            }
        }
        return view
    }

    func updateNSView(_ nsView: KeyHandlingSKView, context: Context) {
        nsView.onKeyEvent = onKeyEvent
        nsView.onWindowNumberChange = onWindowNumberChange
        nsView.claimsKeyboardFocus = claimsKeyboardFocus
        if nsView.scene !== scene {
            nsView.presentScene(scene)
        }

        // Claim focus only on the transition into gameplay — never on every
        // SwiftUI redraw (that steals FocusState from pause/outcome overlays).
        let becameGameplayFocus = claimsKeyboardFocus && !context.coordinator.wasClaimingFocus
        context.coordinator.wasClaimingFocus = claimsKeyboardFocus
        if becameGameplayFocus {
            DispatchQueue.main.async {
                nsView.claimFocusIfNeeded()
            }
        }
    }

    static func dismantleNSView(_ nsView: KeyHandlingSKView, coordinator: Coordinator) {
        nsView.onWindowNumberChange?(nil)
        nsView.onWindowNumberChange = nil
        nsView.onKeyEvent = nil
    }
}
