import AppKit
import CoreGraphics

/// Sends a Control+Shift+digit shortcut to an application.
public protocol ShortcutSending: AnyObject {
    func sendControlShift(digit: Int, to pid: pid_t)
}

/// Synthesises the shortcut with Core Graphics events.
///
/// The modifiers are pressed as real key events rather than set as flags on the
/// digit: Chromium-based apps ignore flag-only modifiers, which is why the
/// obvious implementation looks like it works and changes nothing.
public final class CGEventShortcutSender: ShortcutSending {
    /// Virtual key codes for the digits 1...9.
    private static let digitKeyCodes: [CGKeyCode] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
    private static let controlKey: CGKeyCode = 59
    private static let shiftKey: CGKeyCode = 56

    public init() {}

    public func sendControlShift(digit: Int, to pid: pid_t) {
        guard digit >= 1, digit <= Self.digitKeyCodes.count else { return }
        let key = Self.digitKeyCodes[digit - 1]

        // The shortcut is delivered to the frontmost app, so the target has to
        // be brought forward first.
        NSRunningApplication(processIdentifier: pid)?.activateFrontmost()
        Thread.sleep(forTimeInterval: 0.15)

        let source = CGEventSource(stateID: .hidSystemState)

        func post(_ code: CGKeyCode, down: Bool, flags: CGEventFlags) {
            let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.02)
        }

        post(Self.controlKey, down: true, flags: [.maskControl])
        post(Self.shiftKey, down: true, flags: [.maskControl, .maskShift])
        post(key, down: true, flags: [.maskControl, .maskShift])
        post(key, down: false, flags: [.maskControl, .maskShift])
        post(Self.shiftKey, down: false, flags: [.maskControl])
        post(Self.controlKey, down: false, flags: [])
    }
}
