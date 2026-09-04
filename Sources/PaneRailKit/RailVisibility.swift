import Foundation

/// Everything the show/hide decision depends on except how many rows there
/// are, which arrives separately because it is only known after a provider has
/// been asked — and asking is exactly what this lets a caller skip.
public struct RailVisibilityInput {
    public let isEnabled: Bool
    public let isAccessibilityTrusted: Bool
    public let bundleIdentifier: String?
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

    public static func shouldShow(_ input: RailVisibilityInput, itemCount: Int) -> Bool {
        isEligible(input) && meetsThreshold(itemCount: itemCount, minimumItems: input.minimumItems)
    }

    /// The second half of the rule: enough rows to be worth showing. A stored
    /// threshold below one must not be read as "show an app with no rows".
    public static func meetsThreshold(itemCount: Int, minimumItems: Int) -> Bool {
        itemCount >= max(1, minimumItems)
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
        case .exceptListedApps:
            return !input.listedBundleIDs.contains(bundleID)
        }
    }
}
