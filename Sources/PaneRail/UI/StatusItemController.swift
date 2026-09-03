import AppKit
import Combine
import PaneRailKit

/// Menu bar entry. The app has no Dock tile, so this is the only always-visible
/// way back into settings.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let preferences: Preferences
    private let authorizer: AccessibilityAuthorizer
    private var cancellables = Set<AnyCancellable>()
    private let onOpenSettings: () -> Void
    private let onOpenAccessibilitySettings: () -> Void
    private let onQuit: () -> Void

    private let enabledItem = NSMenuItem(title: "Rail Enabled", action: nil, keyEquivalent: "")
    private let permissionItem = NSMenuItem(title: "Grant Accessibility Access…", action: nil, keyEquivalent: "")

    init(
        preferences: Preferences,
        authorizer: AccessibilityAuthorizer,
        onOpenSettings: @escaping () -> Void,
        onOpenAccessibilitySettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.authorizer = authorizer
        self.onOpenSettings = onOpenSettings
        self.onOpenAccessibilitySettings = onOpenAccessibilitySettings
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        statusItem.menu = makeMenu()

        // Mirrors how other permission-hungry utilities flag themselves: the
        // glyph itself becomes the warning, so the problem is visible without
        // opening the menu.
        authorizer.$isTrusted
            .receive(on: RunLoop.main)
            .sink { [weak self] trusted in self?.updateIcon(trusted: trusted) }
            .store(in: &cancellables)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        enabledItem.target = self
        enabledItem.action = #selector(toggleEnabled)
        menu.addItem(enabledItem)

        permissionItem.target = self
        permissionItem.action = #selector(openAccessibilitySettings)
        menu.addItem(permissionItem)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About PaneRail", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit PaneRail", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private func updateIcon(trusted: Bool) {
        guard let button = statusItem.button else { return }
        let symbol = trusted ? "macwindow.on.rectangle" : "exclamationmark.triangle.fill"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "PaneRail")
        image?.isTemplate = true
        button.image = image
        button.toolTip = trusted
            ? "PaneRail"
            : "PaneRail needs Accessibility access"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        enabledItem.state = preferences.isEnabled ? .on : .off
        // Only worth showing while the permission is actually missing.
        permissionItem.isHidden = authorizer.isTrusted
    }

    @objc private func toggleEnabled() {
        preferences.isEnabled.toggle()
    }

    @objc private func showAbout() {
        // An accessory app has to come forward or the panel opens behind
        // whatever the user was looking at.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func openAccessibilitySettings() {
        onOpenAccessibilitySettings()
    }

    @objc private func quit() {
        onQuit()
    }
}
