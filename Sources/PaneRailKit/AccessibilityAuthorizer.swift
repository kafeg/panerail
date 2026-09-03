import AppKit
import ApplicationServices
import Combine

/// Tracks whether the app holds Accessibility trust, and nudges the user
/// towards granting it.
///
/// macOS posts no notification when a TCC switch is flipped, so the state is
/// polled. Publishing it lets the settings window and the menu bar icon react
/// the moment access is granted or revoked.
public final class AccessibilityAuthorizer: ObservableObject {
    @Published public private(set) var isTrusted: Bool

    public static var isProcessTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system's "grant access" alert. Safe to call repeatedly; macOS
    /// surfaces the alert only once per app per session.
    public static func promptForTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    public static func openSystemSettings() {
        let path = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        guard let url = URL(string: path) else { return }
        NSWorkspace.shared.open(url)
    }

    public var onChange: ((Bool) -> Void)?
    private var timer: Timer?

    public init() {
        isTrusted = Self.isProcessTrusted
    }

    deinit { stopMonitoring() }

    public func startMonitoring(interval: TimeInterval = 1.0) {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        // Common mode so the state keeps updating while a menu is tracking.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let trusted = Self.isProcessTrusted
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        onChange?(trusted)
    }
}
