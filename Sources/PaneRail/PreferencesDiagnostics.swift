import Foundation
import PaneRailKit

/// Round-trip check for the settings store, driven from the command line.
///
/// `--preferences-write` stores a known value in every setting and exits;
/// `--preferences-dump` reports what a fresh launch reads back. Running one
/// then the other exercises the real save and load paths rather than a test
/// double.
enum PreferencesDiagnostics {
    static func dump(_ preferences: Preferences) -> String {
        let origin = preferences.savedOrigin.map { "\(Int($0.x)),\(Int($0.y))" } ?? "none"
        return """
        isEnabled=\(preferences.isEnabled)
        mode=\(preferences.mode.rawValue)
        minimumWindows=\(preferences.minimumWindows)
        listedBundleIDs=\(preferences.listedBundleIDs.joined(separator: "|"))
        appSpecificProviders=\(preferences.appSpecificProviders)
        hidesInFullScreen=\(preferences.hidesInFullScreen)
        width=\(Int(preferences.width))
        savedOrigin=\(origin)
        """
    }

    /// Deliberately different from every default, so a value that survives
    /// cannot be a default in disguise.
    static func writeProbeValues(_ preferences: Preferences) {
        preferences.isEnabled = false
        preferences.mode = .listedApps
        preferences.minimumWindows = 5
        preferences.listedBundleIDs = ["com.example.one", "com.example.two"]
        preferences.appSpecificProviders = true
        preferences.hidesInFullScreen = false
        preferences.width = 310
        preferences.savedOrigin = CGPoint(x: 321, y: 654)
    }
}
