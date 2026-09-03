import SwiftUI

/// Bridges `NSVisualEffectView` so the rail gets the same translucency as
/// native HUD panels.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}

/// Invisible drag surface. The rail has no title bar, so the header doubles as
/// the handle; rows stay clickable because only the header carries this.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ view: NSView, context: Context) {}

    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        // The panel never becomes key, so every click is a "first mouse".
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }
}
