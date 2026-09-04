import PaneRailKit

extension VivaldiWorkspacesStatus {
    var isHealthy: Bool {
        if case .ok = self { return true }
        return false
    }

    var summary: String {
        switch self {
        case .ok(let count):
            return "\(count) workspace\(count == 1 ? "" : "s") found in Vivaldi's profile."
        case .noWorkspaces:
            return "Vivaldi's profile has no workspaces yet."
        case .profileNotFound:
            return "No Vivaldi profile found. Is Vivaldi installed?"
        case .unreadable:
            return "Vivaldi's profile could not be read."
        case .unexpectedLayout:
            return "Vivaldi's profile no longer stores workspaces where PaneRail looks — most likely a Vivaldi update. The rail falls back to windows."
        }
    }
}
