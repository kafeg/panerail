import AppKit
import ApplicationServices

/// Reports which Vivaldi workspace is currently active.
public protocol VivaldiActiveWorkspaceReading: AnyObject {
    func activeIndex(among workspaces: [VivaldiWorkspace], pid: pid_t) -> Int?
}

/// Derives the active workspace from Vivaldi's "Other Workspaces and Tabs"
/// menu, which lists every workspace except the one currently in use. The
/// active one is therefore whichever is missing.
///
/// The menu is found once and the element cached: Vivaldi's menu bar holds a
/// couple of thousand items, and the rail polls several times a second, so
/// re-walking the tree every time would be wasteful.
public final class AXVivaldiActiveWorkspaceReader: VivaldiActiveWorkspaceReading {
    /// Enough matching titles to be sure this is the workspace menu and not a
    /// coincidence.
    private static let confidenceThreshold = 2

    private var cachedMenu: AXUIElement?
    private var cachedForPID: pid_t?

    public init() {}

    public func activeIndex(among workspaces: [VivaldiWorkspace], pid: pid_t) -> Int? {
        guard workspaces.count > 1 else { return nil }

        if let index = missingWorkspace(among: workspaces, in: cachedMenuIfValid(for: pid)) {
            return index
        }

        // The cached element goes stale when Vivaldi rebuilds its menus.
        cachedMenu = locateWorkspaceMenu(pid: pid, workspaces: workspaces)
        cachedForPID = pid
        return missingWorkspace(among: workspaces, in: cachedMenu)
    }

    private func cachedMenuIfValid(for pid: pid_t) -> AXUIElement? {
        cachedForPID == pid ? cachedMenu : nil
    }

    /// Exactly one absent workspace identifies the active one. Zero or several
    /// means the menu is not in a state we can read, and no row is highlighted
    /// rather than the wrong one.
    private func missingWorkspace(among workspaces: [VivaldiWorkspace], in menu: AXUIElement?) -> Int? {
        guard let menu, let children = Self.copy(menu, kAXChildrenAttribute) as? [AXUIElement] else {
            return nil
        }

        var present = Set<Int>()
        for child in children {
            guard let title = Self.string(child, kAXTitleAttribute) else { continue }
            if let hit = workspaces.first(where: { $0.name == title }) { present.insert(hit.index) }
        }
        guard present.count >= Self.confidenceThreshold else { return nil }

        let missing = workspaces.map(\.index).filter { !present.contains($0) }
        return missing.count == 1 ? missing[0] : nil
    }

    /// Walks the menu bar only — never the web content — looking for the
    /// submenu that lists workspace names. Menu titles are localised, so the
    /// menu is identified by its contents rather than by its name.
    private func locateWorkspaceMenu(pid: pid_t, workspaces: [VivaldiWorkspace]) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        guard let menuBar = Self.copyElement(app, "AXMenuBar"),
              let barItems = Self.copy(menuBar, kAXChildrenAttribute) as? [AXUIElement]
        else { return nil }

        for barItem in barItems {
            guard let menus = Self.copy(barItem, kAXChildrenAttribute) as? [AXUIElement] else { continue }
            for menu in menus {
                guard let items = Self.copy(menu, kAXChildrenAttribute) as? [AXUIElement] else { continue }
                for item in items {
                    guard let submenus = Self.copy(item, kAXChildrenAttribute) as? [AXUIElement] else { continue }
                    for submenu in submenus where matchCount(in: submenu, workspaces: workspaces) >= Self.confidenceThreshold {
                        return submenu
                    }
                }
            }
        }
        return nil
    }

    private func matchCount(in menu: AXUIElement, workspaces: [VivaldiWorkspace]) -> Int {
        guard let children = Self.copy(menu, kAXChildrenAttribute) as? [AXUIElement] else { return 0 }
        return children.reduce(into: 0) { total, child in
            guard let title = Self.string(child, kAXTitleAttribute) else { return }
            if workspaces.contains(where: { $0.name == title }) { total += 1 }
        }
    }

    private static func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copy(element, attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        copy(element, attribute) as? String
    }
}
