import Foundation

/// The running app's version, as shown in the settings window and the About
/// panel.
public enum AppVersion {
    public static var marketing: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    public static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    public static var display: String {
        display(marketing: marketing, build: build)
    }

    /// Kept separate from `Bundle.main` so the formatting can be tested — inside
    /// a test bundle the main bundle is the test runner, not the app.
    ///
    /// The build number only earns its place when it says something the version
    /// does not, which for a release built straight from a tag it does not.
    public static func display(marketing: String, build: String) -> String {
        let version = marketing.trimmingCharacters(in: .whitespaces)
        let build = build.trimmingCharacters(in: .whitespaces)

        guard !version.isEmpty else { return build.isEmpty ? "" : "build \(build)" }
        guard !build.isEmpty, build != version, build != "1" else { return version }
        // The version's last component is the build number, so printing it
        // again in brackets says nothing.
        guard !version.hasSuffix(".\(build)") else { return version }
        return "\(version) (\(build))"
    }
}
