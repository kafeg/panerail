import AppKit
import PaneRailKit
import SwiftUI

/// Renders the rail off-screen to a PNG.
///
/// Used for README screenshots and for eyeballing layout changes without
/// needing a Screen Recording grant to capture the real window.
enum PreviewRenderer {
    static func render(to path: String, dark: Bool) -> Bool {
        let suite = UserDefaults(suiteName: "dev.kafeg.panerail.preview") ?? .standard
        suite.removePersistentDomain(forName: "dev.kafeg.panerail.preview")

        let preferences = Preferences(defaults: suite)
        let coordinator = RailCoordinator(source: DemoData.makeSource(), preferences: preferences)
        coordinator.setFrontmost(DemoData.app)

        let railSize = RailGeometry.panelSize(
            itemCount: coordinator.items.count,
            width: CGFloat(preferences.width)
        )

        let rail = RailView(
            coordinator: coordinator,
            preferences: preferences,
            onOpenSettings: {},
            onSelect: { _ in }
        )

        return draw(rail: rail, size: railSize, dark: dark, to: path)
    }

    private static func draw(rail: RailView, size: CGSize, dark: Bool, to path: String) -> Bool {
        let hosting = NSHostingView(rootView: rail)
        hosting.frame = CGRect(origin: .zero, size: size)

        // The blur of `NSVisualEffectView` has nothing to sample off-screen, so
        // the rail is composited over a flat backdrop instead.
        let padding: CGFloat = 28
        let container = BackdropView(frame: CGRect(
            origin: .zero,
            size: CGSize(width: size.width + padding * 2, height: size.height + padding * 2)
        ))
        container.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        container.addSubview(hosting)
        hosting.frame.origin = CGPoint(x: padding, y: padding)
        container.layoutSubtreeIfNeeded()

        guard let rep = container.bitmapImageRepForCachingDisplay(in: container.bounds) else {
            return false
        }
        container.cacheDisplay(in: container.bounds, to: rep)

        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: URL(fileURLWithPath: path))) != nil
    }

    /// Renders the rail against a real running application, so the README
    /// shows the app's own icon and genuine window titles rather than a mock-up.
    ///
    /// Needs the Accessibility grant, so it has to be launched through `open`.
    static func renderLive(
        bundleIdentifier: String,
        to path: String,
        dark: Bool,
        iconStrip: Bool = false
    ) -> Bool {
        guard AccessibilityAuthorizer.isProcessTrusted else {
            print("no accessibility permission")
            return false
        }
        guard let running = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleIdentifier
        }), let app = FrontmostApp(running: running) else {
            print("\(bundleIdentifier) is not running")
            return false
        }

        let suite = UserDefaults(suiteName: "dev.kafeg.panerail.preview") ?? .standard
        suite.removePersistentDomain(forName: "dev.kafeg.panerail.preview")
        let preferences = Preferences(defaults: suite)
        preferences.appSpecificProviders = true

        let coordinator = RailCoordinator(
            windowProvider: WindowRailProvider(source: AXWindowSource()),
            appSpecificProviders: [VivaldiRailProvider(prefersIconStrip: { iconStrip })],
            preferences: preferences
        )
        coordinator.setFrontmost(app)
        guard !coordinator.items.isEmpty else {
            print("\(app.name) has no windows to show")
            return false
        }

        return draw(
            rail: RailView(
                coordinator: coordinator,
                preferences: preferences,
                onOpenSettings: {},
                onSelect: { _ in }
            ),
            size: RailGeometry.size(
                for: coordinator.layout,
                itemCount: coordinator.items.count,
                width: CGFloat(preferences.width)
            ),
            dark: dark,
            to: path
        )
    }

    /// Renders the horizontal layout, which no other preview can reach: it is
    /// chosen by a provider, not by a setting the renderer could flip.
    static func renderStrip(to path: String, dark: Bool) -> Bool {
        let suite = UserDefaults(suiteName: "dev.kafeg.panerail.preview") ?? .standard
        suite.removePersistentDomain(forName: "dev.kafeg.panerail.preview")
        let preferences = Preferences(defaults: suite)

        let coordinator = RailCoordinator(
            windowProvider: StripPreviewProvider(),
            preferences: preferences
        )
        coordinator.setFrontmost(DemoData.app)

        return draw(
            rail: RailView(
                coordinator: coordinator,
                preferences: preferences,
                onOpenSettings: {},
                onSelect: { _ in }
            ),
            size: RailGeometry.stripSize(itemCount: coordinator.items.count),
            dark: dark,
            to: path
        )
    }

    /// Renders one settings tab's content, so its layout can be checked without
    /// a Screen Recording grant to capture the real window.
    static func renderSettings(to path: String, dark: Bool, advanced: Bool = false) -> Bool {
        let suite = UserDefaults(suiteName: "dev.kafeg.panerail.preview") ?? .standard
        suite.removePersistentDomain(forName: "dev.kafeg.panerail.preview")

        let preferences = Preferences(defaults: suite)
        let view = Group {
            if advanced {
                AdvancedSettingsView(preferences: preferences)
            } else {
                GeneralSettingsView(preferences: preferences, authorizer: AccessibilityAuthorizer())
            }
        }
        .padding(14)

        let size = CGSize(width: 500, height: 485)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: size)

        // Off-screen there is no window behind the view, so its own backdrop
        // has to be supplied or dark-mode text lands on white.
        let container = WindowBackdropView(frame: CGRect(origin: .zero, size: size))
        container.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        container.addSubview(hosting)
        container.layoutSubtreeIfNeeded()

        guard let rep = container.bitmapImageRepForCachingDisplay(in: container.bounds) else {
            return false
        }
        container.cacheDisplay(in: container.bounds, to: rep)

        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: URL(fileURLWithPath: path))) != nil
    }

    private final class WindowBackdropView: NSView {
        override func draw(_ dirtyRect: NSRect) {
            NSColor.windowBackgroundColor.setFill()
            bounds.fill()
        }
    }

    /// Scripted glyphs shaped like Vivaldi's: 16-point outlines that inherit
    /// their colour.
    private final class StripPreviewProvider: RailItemProvider {
        private static let shapes = [
            ("Work", "M8 0.74L9.73 6.27H15.5L10.92 9.71L12.72 15.26L8 11.83L3.28 15.26L5.08 9.71L0.5 6.27H6.27L8 0.74Z"),
            ("Personal", "M3 3H13V13H3V3Z"),
            ("Reading", "M8 1L15 8L8 15L1 8L8 1Z"),
            ("Media", "M2 8H14M8 2V14"),
            ("Archive", "M3 3H13V7H3V3ZM3 9H13V13H3V9Z"),
        ]

        func supports(_ app: FrontmostApp) -> Bool { true }

        func items(for app: FrontmostApp) -> [RailItem] {
            Self.shapes.enumerated().map { index, shape in
                RailItem(
                    id: UInt64(index),
                    title: shape.0,
                    isActive: index == 1,
                    iconSVG: #"<svg viewBox="0 0 16 16" fill="none" stroke="currentColor"><path d="\#(shape.1)"/></svg>"#
                )
            }
        }

        func activate(_ item: RailItem, in app: FrontmostApp) -> Bool { true }

        func layout(for app: FrontmostApp) -> RailLayout { .iconStrip }
    }

    private final class BackdropView: NSView {
        override func draw(_ dirtyRect: NSRect) {
            (effectiveAppearance.name == .darkAqua
                ? NSColor(calibratedWhite: 0.13, alpha: 1)
                : NSColor(calibratedWhite: 0.86, alpha: 1)).setFill()
            bounds.fill()
        }
    }
}
