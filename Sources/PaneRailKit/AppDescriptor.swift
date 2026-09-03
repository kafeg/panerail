import AppKit

/// An application the user can add to the rail's allow list.
public struct AppDescriptor: Identifiable, Equatable {
    public let bundleIdentifier: String
    public let name: String
    public let icon: NSImage?

    public var id: String { bundleIdentifier }

    public init(bundleIdentifier: String, name: String, icon: NSImage? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.icon = icon
    }

    public static func == (lhs: AppDescriptor, rhs: AppDescriptor) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier && lhs.name == rhs.name
    }
}

public enum RunningApps {
    /// Apps with a Dock presence — the only ones with windows worth switching.
    public static func userVisible(excluding excluded: Set<String> = [Bundle.main.bundleIdentifier ?? ""]) -> [AppDescriptor] {
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> AppDescriptor? in
            guard app.activationPolicy == .regular,
                  let bundleID = app.bundleIdentifier,
                  !excluded.contains(bundleID)
            else { return nil }
            return AppDescriptor(
                bundleIdentifier: bundleID,
                name: app.localizedName ?? bundleID,
                icon: app.icon
            )
        }
        return dedupedSorted(apps)
    }

    /// Resolves an allow-listed bundle id that is not currently running, so the
    /// settings list still shows a name and an icon for it.
    public static func descriptor(forBundleIdentifier bundleID: String) -> AppDescriptor? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        return AppDescriptor(
            bundleIdentifier: bundleID,
            name: name,
            icon: NSWorkspace.shared.icon(forFile: url.path)
        )
    }

    public static func dedupedSorted(_ apps: [AppDescriptor]) -> [AppDescriptor] {
        var seen = Set<String>()
        let unique = apps.filter { seen.insert($0.bundleIdentifier).inserted }
        return unique.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
