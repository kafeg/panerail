import ApplicationServices
import Foundation

/// Opaque reference to a live window.
///
/// The accessibility element is kept out of `WindowInfo`'s value semantics so
/// tests can build window lists by hand without touching the AX API.
public struct WindowHandle {
    public let element: AXUIElement

    public init(element: AXUIElement) {
        self.element = element
    }
}

/// A single window belonging to some application.
public struct WindowInfo: Identifiable, Equatable {
    /// Stable for as long as the window lives, so SwiftUI keeps row identity
    /// across refreshes instead of re-animating the whole rail every tick.
    public let id: UInt64
    public let title: String
    public let isMinimized: Bool
    public let isFocused: Bool
    public let handle: WindowHandle?

    public init(
        id: UInt64,
        title: String,
        isMinimized: Bool = false,
        isFocused: Bool = false,
        handle: WindowHandle? = nil
    ) {
        self.id = id
        self.title = title
        self.isMinimized = isMinimized
        self.isFocused = isFocused
        self.handle = handle
    }

    /// Handles are deliberately excluded: the same window re-read from the AX
    /// API yields a fresh element, and that must not count as a change.
    public static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.isMinimized == rhs.isMinimized
            && lhs.isFocused == rhs.isFocused
    }
}

/// Title clean-up shared by the rail rows and the status bar menu.
public enum WindowTitle {
    public static let untitled = "Untitled"

    /// Windows without a title are common (empty editors, some dialogs).
    /// Fall back to the app name so a row is never blank.
    public static func display(rawTitle: String, appName: String) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let app = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        return app.isEmpty ? untitled : app
    }

}
