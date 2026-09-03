import AppKit
import ApplicationServices

/// Reports whether the given application's focused window is filling a screen.
public protocol FullScreenDetecting: AnyObject {
    func isFullScreen(pid: pid_t) -> Bool
}

/// The size comparison behind full-screen detection, kept pure so it can be
/// tested without a window server.
public enum FullScreenGeometry {
    /// A window is treated as full screen when it is at least as large as the
    /// whole display.
    ///
    /// Comparing against the display rather than its visible area is what
    /// separates full screen from merely zoomed: a zoomed window stops below
    /// the menu bar, so it is measurably shorter.
    public static func covers(windowSize: CGSize, screenSize: CGSize, tolerance: CGFloat = 2) -> Bool {
        guard screenSize.width > 0, screenSize.height > 0 else { return false }
        return windowSize.width >= screenSize.width - tolerance
            && windowSize.height >= screenSize.height - tolerance
    }
}

public final class AXFullScreenDetector: FullScreenDetecting {
    public init() {}

    public func isFullScreen(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        guard let window = Self.copyElement(app, kAXFocusedWindowAttribute) else { return false }

        // Native full screen announces itself. Not every app sets this, and
        // Chromium's own "windowed" full screen does not, hence the fallback.
        if let flag = Self.copy(window, "AXFullScreen") as? Bool, flag { return true }

        guard let size = Self.size(of: window) else { return false }
        return NSScreen.screens.contains {
            FullScreenGeometry.covers(windowSize: size, screenSize: $0.frame.size)
        }
    }

    private static func size(of window: AXUIElement) -> CGSize? {
        guard let value = copy(window, kAXSizeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue((value as! AXValue), .cgSize, &size) else { return nil }
        return size
    }

    private static func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copy(element, attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
}
