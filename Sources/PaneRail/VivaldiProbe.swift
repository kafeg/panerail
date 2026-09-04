import AppKit
import ApplicationServices
import CryptoKit
import PaneRailKit

/// Research tool: reports what Vivaldi's accessibility tree exposes about
/// workspaces, so the switching strategy can be based on evidence.
///
/// Deliberately privacy-preserving — workspace names are matched but never
/// printed, only their positions in the list.
enum VivaldiProbe {
    private static let maxDepth = 22
    private static let maxNodes = 60_000

    /// The title of the menu item that owns this menu — Vivaldi's own string.
    private static func ownerLabel(of item: AXUIElement) -> String {
        guard let menu = AXAttribute.value(item, kAXParentAttribute),
              CFGetTypeID(menu) == AXUIElementGetTypeID() else { return "?" }
        guard let owner = AXAttribute.value((menu as! AXUIElement), kAXParentAttribute),
              CFGetTypeID(owner) == AXUIElementGetTypeID() else { return "?" }
        let ownerElement = (owner as! AXUIElement)
        let title = AXAttribute.string(ownerElement, kAXTitleAttribute) ?? ""
        let role = AXAttribute.string(ownerElement, kAXRoleAttribute) ?? "?"
        return title.isEmpty ? role : title
    }

    /// Read-only sweep for the workspace name anywhere in the tree, not just
    /// in menus. Vivaldi's own UI is web content, so if the active workspace
    /// is labelled anywhere it will show up here — and unlike a menu, web
    /// content reflects live state.
    static func live(reportPath: String) {
        var report: [String] = []
        func emit(_ line: String) { report.append(line); print(line) }
        defer {
            try? report.joined(separator: "\n").write(
                toFile: reportPath, atomically: true, encoding: .utf8
            )
        }

        guard AccessibilityAuthorizer.isProcessTrusted else { emit("no accessibility permission"); return }
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == VivaldiWorkspaces.bundleIdentifier
        }) else { emit("Vivaldi is not running"); return }

        let workspaces = VivaldiWorkspaces.load()
        let element = AXUIElementCreateApplication(app.processIdentifier)
        emit("workspaces: \(workspaces.count)")

        var found: [(role: String, subrole: String, attribute: String, index: Int, depth: Int, owner: String)] = []
        var visited = 0

        func walk(_ node: AXUIElement, depth: Int) {
            guard depth <= maxDepth, visited < maxNodes else { return }
            visited += 1
            let role = AXAttribute.string(node, kAXRoleAttribute) ?? "?"
            for attribute in [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute, "AXHelp"] {
                guard let text = AXAttribute.string(node, attribute)?
                    .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { continue }
                if let hit = workspaces.first(where: { $0.name == text }) {
                    found.append((role, AXAttribute.string(node, kAXSubroleAttribute) ?? "",
                                  attribute, hit.index, depth, ownerLabel(of: node)))
                    break
                }
            }
            guard let children = AXAttribute.value(node, kAXChildrenAttribute) as? [AXUIElement] else { return }
            for child in children { walk(child, depth: depth + 1) }
        }
        walk(element, depth: 0)

        emit("visited \(visited) nodes, \(found.count) matches")
        var nonMenu = 0
        for hit in found {
            if hit.role != "AXMenuItem" { nonMenu += 1 }
            emit("  workspace#\(hit.index) role=\(hit.role) subrole=\(hit.subrole) via=\(hit.attribute) depth=\(hit.depth) owner=\(hit.owner)")
        }
        emit("matches outside menus: \(nonMenu)")
    }
}
