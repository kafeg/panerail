import Foundation

/// Everything the show/hide decision depends on, gathered into one value so the
/// rule itself stays a pure function.
public struct RailVisibilityInput {
    public let isEnabled: Bool
    public let isAccessibilityTrusted: Bool
    public let bundleIdentifier: String?
    public let itemCount: Int
    public let mode: RailMode
    public let minimumItems: Int
    public let listedBundleIDs: Set<String>
    public let excludedBundleIDs: Set<String>
    public let isFullScreen: Bool
    public let hidesInFullScreen: Bool

    public init(
        isEnabled: Bool = true,
        isAccessibilityTrusted: Bool = true,
        bundleIdentifier: String?,
        itemCount: Int,
        mode: RailMode = .allApps,
        minimumItems: Int = 2,
        listedBundleIDs: Set<String> = [],
        excludedBundleIDs: Set<String> = RailVisibility.defaultExclusions,
        isFullScreen: Bool = false,
        hidesInFullScreen: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.bundleIdentifier = bundleIdentifier
        self.itemCount = itemCount
        self.mode = mode
        self.minimumItems = minimumItems
        self.listedBundleIDs = listedBundleIDs
        self.excludedBundleIDs = excludedBundleIDs
        self.isFullScreen = isFullScreen
        self.hidesInFullScreen = hidesInFullScreen
    }
}

public enum RailVisibility {
    /// Our own bundle plus the shells that own the desktop; showing a window
    /// switcher over any of them is noise at best.
    public static let defaultExclusions: Set<String> = [
        "dev.kafeg.panerail",
        "com.apple.loginwindow",
        "com.apple.ScreenSaver.Engine",
        "com.apple.WindowManager",
    ]

    public static func shouldShow(_ input: RailVisibilityInput) -> Bool {
        guard isEligible(input) else { return false }
        return input.itemCount >= max(1, input.minimumItems)
    }

    /// Everything the decision depends on except how many rows there are.
    ///
    /// Separated so a caller can rule an app out before doing the work of
    /// collecting its rows: an app the user has not ticked can never show the
    /// rail, whatever a provider would have found for it.
    public static func isEligible(_ input: RailVisibilityInput) -> Bool {
        guard input.isEnabled, input.isAccessibilityTrusted else { return false }
        guard let bundleID = input.bundleIdentifier, !bundleID.isEmpty else { return false }
        guard !input.excludedBundleIDs.contains(bundleID) else { return false }
        guard !(input.isFullScreen && input.hidesInFullScreen) else { return false }

        switch input.mode {
        case .allApps:
            return true
        case .listedApps:
            return input.listedBundleIDs.contains(bundleID)
        }
    }
}
