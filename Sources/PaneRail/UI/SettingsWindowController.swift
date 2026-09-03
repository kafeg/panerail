import AppKit
import PaneRailKit
import SwiftUI

final class SettingsWindowController {
    private let preferences: Preferences
    private let authorizer: AccessibilityAuthorizer
    private var window: NSWindow?

    init(preferences: Preferences, authorizer: AccessibilityAuthorizer) {
        self.preferences = preferences
        self.authorizer = authorizer
    }

    func show() {
        if window == nil {
            window = makeWindow()
            window?.center()
        }
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PaneRail Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: SettingsView(preferences: preferences, authorizer: authorizer)
        )
        return window
    }
}

final class OnboardingWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            window = makeWindow()
            window?.center()
        }
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to PaneRail"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: OnboardingView(onRequestAccess: { [weak self] in
            // Register the app in the Accessibility list, put the pane in
            // front of the user, and get out of the way.
            AccessibilityAuthorizer.promptForTrust()
            AccessibilityAuthorizer.openSystemSettings()
            self?.close()
        }))
        return window
    }
}
