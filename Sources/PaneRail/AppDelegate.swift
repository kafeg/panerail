import AppKit
import Combine
import PaneRailKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// `--demo` swaps the AX window source for scripted data so the UI can be
    /// developed, screenshotted and reviewed without an Accessibility grant.
    private let isDemo = CommandLine.arguments.contains("--demo")

    private let preferences = Preferences()
    private let authorizer = AccessibilityAuthorizer()
    private var monitor: FrontmostAppMonitor?
    private var coordinator: RailCoordinator?
    private var railController: RailWindowController?
    private var statusItemController: StatusItemController?
    private var settingsController: SettingsWindowController?
    private var onboardingController: OnboardingWindowController?
    private var pollTimer: Timer?

    /// AX gives no notification for "a window was renamed", and observers have
    /// to be re-registered whenever the front app changes. Polling one app at a
    /// time is cheap and far less fragile.
    private static let pollInterval: TimeInterval = 0.7

    func applicationDidFinishLaunching(_ notification: Notification) {
        let dark = CommandLine.arguments.contains("--dark")

        if let index = CommandLine.arguments.firstIndex(of: "--render-live"),
           let bundleID = CommandLine.arguments[safe: index + 1],
           let path = CommandLine.arguments[safe: index + 2] {
            let ok = PreviewRenderer.renderLive(bundleIdentifier: bundleID, to: path, dark: dark)
            NSApp.terminate(nil)
            exit(ok ? 0 : 1)
        }

        if let index = CommandLine.arguments.firstIndex(of: "--render-preview"),
           let path = CommandLine.arguments[safe: index + 1] {
            let ok = PreviewRenderer.render(to: path, dark: dark)
            NSApp.terminate(nil)
            exit(ok ? 0 : 1)
        }

        if let index = CommandLine.arguments.firstIndex(of: "--render-settings"),
           let path = CommandLine.arguments[safe: index + 1] {
            let ok = PreviewRenderer.renderSettings(to: path, dark: dark)
            NSApp.terminate(nil)
            exit(ok ? 0 : 1)
        }

        if let index = CommandLine.arguments.firstIndex(of: "--probe-vivaldi-live") {
            let path = CommandLine.arguments[safe: index + 1]
                ?? NSTemporaryDirectory() + "panerail-vivaldi-live.txt"
            VivaldiProbe.live(reportPath: path)
            exit(0)
        }

        let demo = isDemo
        let source: WindowSource = demo ? DemoData.makeSource() : AXWindowSource()

        let coordinator = RailCoordinator(
            windowProvider: WindowRailProvider(source: source),
            // Apps that keep their own internal states get first refusal on
            // describing themselves; the window provider is the fallback.
            appSpecificProviders: demo ? [] : [VivaldiRailProvider()],
            preferences: preferences,
            isTrusted: { demo || AccessibilityAuthorizer.isProcessTrusted }
        )
        self.coordinator = coordinator

        railController = RailWindowController(
            coordinator: coordinator,
            preferences: preferences,
            onOpenSettings: { [weak self] in self?.showSettings() }
        )

        statusItemController = StatusItemController(
            preferences: preferences,
            authorizer: authorizer,
            onOpenSettings: { [weak self] in self?.showSettings() },
            onOpenAccessibilitySettings: { AccessibilityAuthorizer.openSystemSettings() },
            onQuit: { NSApp.terminate(nil) }
        )

        if demo {
            coordinator.setFrontmost(DemoData.app)
        } else {
            let monitor = FrontmostAppMonitor()
            monitor.onChange = { [weak coordinator] app in coordinator?.setFrontmost(app) }
            monitor.start()
            self.monitor = monitor
        }

        startPolling()

        // Monitored even in demo mode so the settings window and the menu bar
        // icon always report the real permission state.
        authorizer.onChange = { [weak self] trusted in
            guard let self else { return }
            if trusted { self.onboardingController?.close() }
            self.coordinator?.refresh()
        }
        authorizer.startMonitoring()

        guard !demo else { return }

        if !AccessibilityAuthorizer.isProcessTrusted {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollTimer?.invalidate()
        monitor?.stop()
        authorizer.stopMonitoring()
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.coordinator?.refresh()
        }
        // Keep refreshing while a menu is tracking, otherwise the rail freezes
        // the moment the user opens the status item.
        RunLoop.main.add(pollTimer!, forMode: .common)
    }

    // MARK: - Auxiliary windows

    private func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(preferences: preferences, authorizer: authorizer)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsController?.show()
    }

    private func showOnboarding() {
        if onboardingController == nil {
            onboardingController = OnboardingWindowController()
        }
        NSApp.activate(ignoringOtherApps: true)
        onboardingController?.show()
    }
}


private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
