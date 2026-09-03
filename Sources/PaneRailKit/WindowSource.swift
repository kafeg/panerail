import AppKit
import ApplicationServices

/// Where the rail gets its windows from.
///
/// The AX-backed implementation needs a real Accessibility grant, so every
/// consumer talks to this protocol and tests inject `FakeWindowSource`.
public protocol WindowSource: AnyObject {
    func windows(for pid: pid_t) -> [WindowInfo]

    @discardableResult
    func raise(_ window: WindowInfo, pid: pid_t) -> Bool
}

/// Reads and manipulates windows through the macOS Accessibility API.
///
/// Deliberately avoids `CGWindowListCopyWindowInfo`: since Catalina it only
/// returns window titles when the app holds the Screen Recording permission,
/// which we do not want to ask for.
public final class AXWindowSource: WindowSource {
    public init() {}

    public func windows(for pid: pid_t) -> [WindowInfo] {
        let app = AXUIElementCreateApplication(pid)
        guard let elements = Self.copyAttribute(app, kAXWindowsAttribute) as? [AXUIElement] else {
            return []
        }

        let focusedElement = Self.copyElement(app, kAXFocusedWindowAttribute)

        return elements.compactMap { element in
            guard Self.isStandardWindow(element) else { return nil }

            let title = (Self.copyAttribute(element, kAXTitleAttribute) as? String) ?? ""
            let minimized = (Self.copyAttribute(element, kAXMinimizedAttribute) as? Bool) ?? false
            let isFocused = focusedElement.map { CFEqual($0, element) } ?? false

            return WindowInfo(
                id: UInt64(CFHash(element)),
                title: title,
                isMinimized: minimized,
                isFocused: isFocused,
                handle: WindowHandle(element: element)
            )
        }
    }

    @discardableResult
    public func raise(_ window: WindowInfo, pid: pid_t) -> Bool {
        guard let element = window.handle?.element else { return false }

        if window.isMinimized {
            AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }

        let raised = AXUIElementPerformAction(element, kAXRaiseAction as CFString) == .success
        // Raising only reorders within the owning app; making it main plus
        // activating the app is what actually brings it to the front.
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        let activated = NSRunningApplication(processIdentifier: pid)?.activateFrontmost() ?? false

        return raised || activated
    }

    /// Palettes, sheets and drawers are windows too. Only standard ones belong
    /// in a switcher; apps that omit the subrole get the benefit of the doubt.
    private static func isStandardWindow(_ element: AXUIElement) -> Bool {
        guard let role = copyAttribute(element, kAXRoleAttribute) as? String, role == kAXWindowRole else {
            return false
        }
        guard let subrole = copyAttribute(element, kAXSubroleAttribute) as? String else {
            return true
        }
        return subrole == kAXStandardWindowSubrole
    }

    /// `as?` is unreliable across the CF/AX boundary, so the type is checked
    /// explicitly before downcasting.
    private static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copyAttribute(element, attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private static func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }
}

/// Scripted window source used by `--demo` mode and the unit tests.
public final class FakeWindowSource: WindowSource {
    public var windowsByPID: [pid_t: [WindowInfo]]
    public private(set) var raiseCalls: [(window: WindowInfo, pid: pid_t)] = []
    public var raiseResult = true

    public init(windowsByPID: [pid_t: [WindowInfo]] = [:]) {
        self.windowsByPID = windowsByPID
    }

    public func windows(for pid: pid_t) -> [WindowInfo] {
        windowsByPID[pid] ?? []
    }

    @discardableResult
    public func raise(_ window: WindowInfo, pid: pid_t) -> Bool {
        raiseCalls.append((window, pid))
        return raiseResult
    }
}

extension NSRunningApplication {
    /// `activate(options:)` is deprecated from macOS 14 onwards.
    @discardableResult
    func activateFrontmost() -> Bool {
        if #available(macOS 14.0, *) {
            return activate()
        } else {
            return activate(options: [.activateIgnoringOtherApps])
        }
    }
}
