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
/// - The active workspace is read back from the "Other Workspaces and Tabs"
///   menu, which lists everything except the workspace in use; the one missing
///   from it is the active one. When that cannot be established unambiguously,
///   no row is highlighted rather than the wrong one.
public final class VivaldiRailProvider: RailItemProvider {
    /// Ctrl+Shift+1 selects the window's own tabs — the entry with no
    /// workspace — so the first workspace answers to the second digit.
    static let firstWorkspaceDigit = 2
    private static let highestDigit = 9

    /// How many workspaces Vivaldi's own shortcuts can reach.
    public static let switchableCount = highestDigit - firstWorkspaceDigit + 1

    private let sender: ShortcutSending
    private let activeReader: VivaldiActiveWorkspaceReading?
    private let preferencesURL: URL
    private var cached: [VivaldiWorkspace] = []
    private var cachedAt: Date?

    public init(
        sender: ShortcutSending = CGEventShortcutSender(),
        activeReader: VivaldiActiveWorkspaceReading? = AXVivaldiActiveWorkspaceReader(),
        preferencesURL: URL = VivaldiWorkspaces.preferencesURL()
    ) {
        self.sender = sender
        self.activeReader = activeReader
        self.preferencesURL = preferencesURL
    }

    /// The digit of the built-in shortcut for a workspace, or `nil` when it is
    /// past the end of what Vivaldi binds.
    static func shortcutDigit(forWorkspaceAt index: Int) -> Int? {
        let digit = index + firstWorkspaceDigit
        return digit <= highestDigit ? digit : nil
    }

    public func supports(_ app: FrontmostApp) -> Bool {
        app.bundleIdentifier == VivaldiWorkspaces.bundleIdentifier && !workspaces().isEmpty
    }

    public func items(for app: FrontmostApp) -> [RailItem] {
        let list = workspaces()
        let active = activeReader?.activeIndex(among: list, pid: app.pid)

        return list.map { workspace in
            RailItem(
                id: UInt64(workspace.index),
                title: workspace.name,
                isActive: workspace.index == active,
                // Past the last bound shortcut there is nothing to send, so
                // those rows are shown but visibly inert rather than dead.
                isDimmed: Self.shortcutDigit(forWorkspaceAt: workspace.index) == nil
            )
        }
    }

    @discardableResult
    public func activate(_ item: RailItem, in app: FrontmostApp) -> Bool {
        guard let digit = Self.shortcutDigit(forWorkspaceAt: Int(item.id)) else { return false }
        sender.sendControlShift(digit: digit, to: app.pid)
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
