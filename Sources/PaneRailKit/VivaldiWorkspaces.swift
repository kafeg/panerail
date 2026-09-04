import Foundation

/// One Vivaldi workspace.
public struct VivaldiWorkspace: Identifiable, Equatable {
    /// Vivaldi's own identifier — a creation timestamp, stored as a number.
    public let id: Double
    public let name: String
    /// Position in Vivaldi's list, which is also the number used by the
    /// built-in `Ctrl+Shift+<n>` shortcut. Zero-based here.
    public let index: Int
    /// The workspace's glyph, stored by Vivaldi as inline SVG markup rather
    /// than a reference into an icon set, so it can be drawn as-is.
    public let icon: String?

    public init(id: Double, name: String, index: Int, icon: String? = nil) {
        self.id = id
        self.name = name
        self.index = index
        self.icon = icon
    }
}

public enum VivaldiWorkspacesError: Error, Equatable {
    case unreadable
    case unexpectedLayout
}

/// Reads Vivaldi's workspaces out of its profile.
///
/// Vivaldi exposes no API for this: the `vivaldi.*` JavaScript namespace is
/// reachable only from its own bundled UI, its AppleScript dictionary is the
/// stock Chromium one, and third-party extensions get neither. The workspace
/// list does sit in the profile's `Preferences` JSON, so that is where it is
/// read from.
///
/// This is undocumented internal structure and a Vivaldi update may move it,
/// so every failure is soft: callers fall back to plain window switching.
public enum VivaldiWorkspaces {
    public static let bundleIdentifier = "com.vivaldi.Vivaldi"

    public static func preferencesURL(profile: String = "Default") -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/Vivaldi")
            .appendingPathComponent(profile)
            .appendingPathComponent("Preferences")
    }

    /// Pure so the layout handling can be tested against fixtures rather than
    /// against whatever happens to be installed.
    public static func parse(preferences data: Data) throws -> [VivaldiWorkspace] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VivaldiWorkspacesError.unreadable
        }
        guard let vivaldi = root["vivaldi"] as? [String: Any],
              let workspaces = vivaldi["workspaces"] as? [String: Any],
              let list = workspaces["list"] as? [[String: Any]]
        else {
            throw VivaldiWorkspacesError.unexpectedLayout
        }

        return list.enumerated().compactMap { index, item in
            guard let name = (item["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty
            else { return nil }
            let id = (item["id"] as? NSNumber)?.doubleValue ?? Double(index)
            return VivaldiWorkspace(id: id, name: name, index: index, icon: item["icon"] as? String)
        }
    }

    public static func load(from url: URL? = nil) -> [VivaldiWorkspace] {
        let url = url ?? preferencesURL()
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? parse(preferences: data)) ?? []
    }
}
