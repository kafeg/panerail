import Foundation

/// Shows Vivaldi's workspaces instead of its windows.
///
/// Switching between workspaces is the thing Vivaldi makes awkward — the picker
/// is a dropdown at the top of the window — and workspaces live inside a single
/// window, so plain window switching does not help at all.
///
/// What this can and cannot do was established by probing a running Vivaldi:
///
/// - The workspace list is read from the profile's `Preferences`; Vivaldi
///   exposes no API for it, and the `vivaldi.*` JavaScript namespace is
///   reachable only from its own bundled UI.
/// - Switching goes through the built-in `Ctrl+Shift+<n>` shortcut. Pressing
///   the matching menu item over the accessibility API reports success and does
///   nothing, because Chromium wires those items up only while the menu is open.
/// - The active workspace is not reported. Its name appears nowhere in the
///   accessibility tree except inside the "Other Workspaces and Tabs" menu,
///   which omits the active one — but Chromium rebuilds that menu lazily, so
///   just after a switch it still describes the previous state. Rather than
///   highlight the wrong row, no row is marked active.
public final class VivaldiRailProvider: RailItemProvider {
    /// Vivaldi's own shortcuts only cover the first nine workspaces.
    public static let switchableCount = 9

    private let sender: ShortcutSending
    private let preferencesURL: URL
    private var cached: [VivaldiWorkspace] = []
    private var cachedAt: Date?

    public init(
        sender: ShortcutSending = CGEventShortcutSender(),
        preferencesURL: URL = VivaldiWorkspaces.preferencesURL()
    ) {
        self.sender = sender
        self.preferencesURL = preferencesURL
    }

    public func supports(_ app: FrontmostApp) -> Bool {
        app.bundleIdentifier == VivaldiWorkspaces.bundleIdentifier && !workspaces().isEmpty
    }

    public func items(for app: FrontmostApp) -> [RailItem] {
        workspaces().map { workspace in
            RailItem(
                id: UInt64(workspace.index),
                title: workspace.name,
                isActive: false,
                // Beyond the ninth there is no shortcut to send, so those rows
                // are shown but visibly inert rather than silently dead.
                isDimmed: workspace.index >= Self.switchableCount
            )
        }
    }

    @discardableResult
    public func activate(_ item: RailItem, in app: FrontmostApp) -> Bool {
        let index = Int(item.id)
        guard index < Self.switchableCount else { return false }
        sender.sendControlShift(digit: index + 1, to: app.pid)
        return true
    }

    /// The profile file is large and the rail polls often, so it is re-read
    /// only when it actually changes.
    private func workspaces() -> [VivaldiWorkspace] {
        let modified = (try? FileManager.default.attributesOfItem(atPath: preferencesURL.path)[.modificationDate]) as? Date
        if let modified, modified == cachedAt { return cached }
        cached = VivaldiWorkspaces.load(from: preferencesURL)
        cachedAt = modified
        return cached
    }
}
