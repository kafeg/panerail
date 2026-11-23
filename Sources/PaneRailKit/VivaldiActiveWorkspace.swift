import AppKit
import ApplicationServices

/// Reports which Vivaldi workspace is currently active.
public protocol VivaldiActiveWorkspaceReading: AnyObject {
    func activeIndex(among workspaces: [VivaldiWorkspace], pid: pid_t) -> Int?
}

/// One look at Vivaldi's window menu, separated from the accessibility reads so
/// that the rule reading it can be tested.
///
/// The menu carries a tab list per workspace: the workspaces it names as
/// *other* each bring their own, and the tabs of the workspace in use sit in
/// the menu itself.
public struct VivaldiMenuReading: Equatable {
    public let tabsByWorkspace: [Int: [String]]
    public let tabsOfWorkspaceInUse: [String]

    public init(tabsByWorkspace: [Int: [String]], tabsOfWorkspaceInUse: [String]) {
        self.tabsByWorkspace = tabsByWorkspace
        self.tabsOfWorkspaceInUse = tabsOfWorkspaceInUse
    }
}

/// Turning a reading of that menu into the active workspace.
///
/// Vivaldi names every workspace except the one in use, so the absent one used
/// to be taken as active. That holds only while the menu is current, and it is
/// not: Vivaldi rebuilds the menu when one of its own shortcuts switches
/// workspace, but a switch made in its interface leaves the menu as it was —
/// still naming the workspace from before as the one in use. Read that way, the
/// menu names the previous workspace with full confidence, which is how the
/// rail came to highlight the wrong row.
///
/// What a menu of any age does hold is which tabs belong to which workspace, so
/// the active one is whichever carries the tab the window is showing — the
/// window title is the one part of this that is always current. Nothing here
/// depends on a menu title, on the order of items, or on anything else a
/// Vivaldi update is free to move.
public enum VivaldiActiveWorkspace {
    /// Enough workspaces named to be sure this is the workspace menu and not a
    /// coincidence.
    public static let confidenceThreshold = 2

    /// A title shorter than this says too little to match a shortened menu
    /// entry, so those have to agree in full.
    static let minimumPrefix = 8

    public static func activeIndex(
        among workspaces: [VivaldiWorkspace],
        reading: VivaldiMenuReading,
        openTab windowTitle: String
    ) -> Int? {
        guard workspaces.count > 1,
              reading.tabsByWorkspace.count >= confidenceThreshold
        else { return nil }

        var holders = reading.tabsByWorkspace
            .filter { menu($0.value, shows: windowTitle) }
            .map(\.key)

        // The menu names every workspace but the one in use, whose tabs it
        // carries itself.
        let unnamed = workspaces.map(\.index).filter { reading.tabsByWorkspace[$0] == nil }
        if unnamed.count == 1, menu(reading.tabsOfWorkspaceInUse, shows: windowTitle) {
            holders.append(unnamed[0])
        }

        // The same page can be open in two workspaces. Then no row is
        // highlighted rather than the wrong one.
        return Set(holders).count == 1 ? holders[0] : nil
    }

    /// Whether a menu holding `entries` is showing `windowTitle`'s tab.
    public static func menu(_ entries: [String], shows windowTitle: String) -> Bool {
        let title = tabTitle(fromWindowTitle: windowTitle)
        guard !title.isEmpty else { return false }
        return entries.contains { entry($0, matches: title) }
    }

    /// The tab title inside a window title, which is `<tab> - Vivaldi`.
    static func tabTitle(fromWindowTitle windowTitle: String) -> String {
        let trimmed = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separator = trimmed.range(of: " - ", options: .backwards) else { return trimmed }
        // Only the application's own suffix is dropped; a page whose own title
        // contains a dash keeps all of it.
        let suffix = trimmed[separator.upperBound...]
        return suffix.contains("Vivaldi") ? String(trimmed[..<separator.lowerBound]) : trimmed
    }

    /// A menu entry is the tab's title shortened to fit, with an ellipsis where
    /// the text was cut — at the end, or in the middle, which is what AppKit
    /// does and what Vivaldi's tab entries actually look like. So an entry
    /// matches when the title begins and ends the way it does.
    private static func entry(_ entry: String, matches title: String) -> Bool {
        // Vivaldi marks the tab a list is showing with a bullet in front of it.
        let shortened = entry
            .drop { $0 == "\u{2022}" || $0.isWhitespace }
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !shortened.isEmpty else { return false }
        if shortened == title { return true }

        let pieces = shortened
            .replacingOccurrences(of: "...", with: "\u{2026}")
            .components(separatedBy: "\u{2026}")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let head = pieces.first, let tail = pieces.last else { return false }

        guard pieces.count > 1 else {
            // Nothing was cut, so a difference is a difference — unless the
            // entry is long enough that agreeing from the start means something.
            guard min(shortened.count, title.count) >= minimumPrefix else { return false }
            return title.hasPrefix(shortened) || shortened.hasPrefix(title)
        }

        guard head.count + tail.count >= minimumPrefix,
              title.count > head.count + tail.count
        else { return false }
        return title.hasPrefix(head) && title.hasSuffix(tail)
    }
}

/// Reads the active workspace from Vivaldi's window menu.
///
/// The menu is found once and its elements cached: Vivaldi's menu bar holds a
/// couple of thousand items, and the rail polls several times a second, so
/// re-walking the tree every time would be wasteful. The elements are looked up
/// again when they stop answering, which is what happens when Vivaldi rebuilds
/// the menu.
public final class AXVivaldiActiveWorkspaceReader: VivaldiActiveWorkspaceReading {
    /// The menu carrying the tabs of the workspace in use, and the list of the
    /// other workspaces inside it.
    private var cachedMenu: AXUIElement?
    private var cachedSubmenu: AXUIElement?
    private var cachedForPID: pid_t?

    /// The answer stands until the window shows another tab or the menu names a
    /// different set of workspaces; reading every tab list on every poll would
    /// be needless work.
    private var lastQuestion: String?
    private var lastAnswer: Int?

    public init() {}

    public func activeIndex(among workspaces: [VivaldiWorkspace], pid: pid_t) -> Int? {
        guard workspaces.count > 1 else { return nil }

        let application = AXUIElementCreateApplication(pid)
        guard let title = windowTitle(of: application) else { return nil }

        if cachedForPID != pid {
            locateWorkspaceMenu(pid: pid, workspaces: workspaces)
            cachedForPID = pid
        }

        var named = namedWorkspaces(among: workspaces)
        if named.count < VivaldiActiveWorkspace.confidenceThreshold {
            // Vivaldi rebuilt the menu and the cached elements went away.
            locateWorkspaceMenu(pid: pid, workspaces: workspaces)
            named = namedWorkspaces(among: workspaces)
        }
        guard named.count >= VivaldiActiveWorkspace.confidenceThreshold else { return nil }

        let question = "\(title)\n\(named.map(\.index).sorted())"
        if question == lastQuestion { return lastAnswer }

        let answer = VivaldiActiveWorkspace.activeIndex(
            among: workspaces,
            reading: reading(named: named, workspaces: workspaces),
            openTab: title
        )
        lastQuestion = question
        lastAnswer = answer
        return answer
    }

    private func windowTitle(of application: AXUIElement) -> String? {
        guard let window = AXAttribute.element(application, kAXFocusedWindowAttribute)
            ?? AXAttribute.elements(application, kAXWindowsAttribute)?.first
        else { return nil }
        return AXAttribute.string(window, kAXTitleAttribute)
    }

    /// The workspaces the cached menu names as other than the one in use, with
    /// the element that carries each one's tabs.
    private func namedWorkspaces(among workspaces: [VivaldiWorkspace]) -> [(index: Int, item: AXUIElement)] {
        guard let cachedSubmenu,
              let items = AXAttribute.elements(cachedSubmenu, kAXChildrenAttribute)
        else { return [] }

        return items.compactMap { item in
            guard let title = AXAttribute.string(item, kAXTitleAttribute),
                  let workspace = workspaces.first(where: { $0.name == title })
            else { return nil }
            return (workspace.index, item)
        }
    }

    private func reading(
        named: [(index: Int, item: AXUIElement)],
        workspaces: [VivaldiWorkspace]
    ) -> VivaldiMenuReading {
        var tabs: [Int: [String]] = [:]
        for workspace in named {
            guard let submenu = AXAttribute.elements(workspace.item, kAXChildrenAttribute)?.first else { continue }
            tabs[workspace.index] = titles(in: submenu)
        }
        return VivaldiMenuReading(
            tabsByWorkspace: tabs,
            tabsOfWorkspaceInUse: tabsOfWorkspaceInUse(workspaces: workspaces)
        )
    }

    private func titles(in menu: AXUIElement) -> [String] {
        (AXAttribute.elements(menu, kAXChildrenAttribute) ?? [])
            .compactMap { AXAttribute.string($0, kAXTitleAttribute) }
    }

    /// The tabs of the workspace in use, which are the menu's own items plus
    /// those of its submenus: pinned tabs sit in one of their own. The list of
    /// workspaces is left out — it names workspaces, not tabs. A submenu of
    /// another window's tabs is taken along, which is a window the user is not
    /// looking at; the price is a title open in both windows reading as this
    /// one's, and the same page in two workspaces already highlights nothing.
    private func tabsOfWorkspaceInUse(workspaces: [VivaldiWorkspace]) -> [String] {
        guard let cachedMenu,
              let items = AXAttribute.elements(cachedMenu, kAXChildrenAttribute)
        else { return [] }

        var tabs = items.compactMap { AXAttribute.string($0, kAXTitleAttribute) }
        for item in items {
            for submenu in AXAttribute.elements(item, kAXChildrenAttribute) ?? [] {
                let entries = titles(in: submenu)
                let named = entries.filter { name in workspaces.contains { $0.name == name } }
                guard named.count < VivaldiActiveWorkspace.confidenceThreshold else { continue }
                tabs += entries
            }
        }
        return tabs
    }

    /// Walks the menu bar only — never the web content — looking for the menu
    /// that carries a list of workspace names. Menu titles are localised, so
    /// both the menu and the list are identified by their contents.
    private func locateWorkspaceMenu(pid: pid_t, workspaces: [VivaldiWorkspace]) {
        cachedMenu = nil
        cachedSubmenu = nil
        lastQuestion = nil

        let application = AXUIElementCreateApplication(pid)
        guard let menuBar = AXAttribute.element(application, "AXMenuBar"),
              let barItems = AXAttribute.elements(menuBar, kAXChildrenAttribute)
        else { return }

        for barItem in barItems {
            guard let menus = AXAttribute.elements(barItem, kAXChildrenAttribute) else { continue }
            for menu in menus {
                guard let items = AXAttribute.elements(menu, kAXChildrenAttribute) else { continue }
                for item in items {
                    guard let submenus = AXAttribute.elements(item, kAXChildrenAttribute) else { continue }
                    for submenu in submenus
                    where matchCount(in: submenu, workspaces: workspaces) >= VivaldiActiveWorkspace.confidenceThreshold {
                        cachedMenu = menu
                        cachedSubmenu = submenu
                        return
                    }
                }
            }
        }
    }

    private func matchCount(in menu: AXUIElement, workspaces: [VivaldiWorkspace]) -> Int {
        guard let children = AXAttribute.elements(menu, kAXChildrenAttribute) else { return 0 }
        return children.reduce(into: 0) { total, child in
            guard let title = AXAttribute.string(child, kAXTitleAttribute) else { return }
            if workspaces.contains(where: { $0.name == title }) { total += 1 }
        }
    }
}
