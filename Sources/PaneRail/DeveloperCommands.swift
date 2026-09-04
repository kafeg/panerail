import AppKit
import PaneRailKit

/// The command-line entry points used to build, screenshot and diagnose the
/// app, kept out of `AppDelegate` so that launching the actual app reads as one
/// short sequence.
///
/// These are developer tools, not a public interface: they are undocumented in
/// the app itself and every one of them exits the process.
enum DeveloperCommands {
    /// Runs whichever command the arguments name, and never returns if one
    /// matched. Returns false when the app should start normally.
    static func runIfRequested(preferences: Preferences) -> Bool {
        let arguments = CommandLine.arguments
        let dark = arguments.contains("--dark")

        func value(after flag: String, offset: Int = 1) -> String? {
            guard let index = arguments.firstIndex(of: flag) else { return nil }
            let position = index + offset
            return arguments.indices.contains(position) ? arguments[position] : nil
        }

        if arguments.contains("--preferences-dump") {
            print(PreferencesDiagnostics.dump(preferences))
            exit(0)
        }

        if arguments.contains("--preferences-write") {
            PreferencesDiagnostics.writeProbeValues(preferences)
            print("written")
            exit(0)
        }

        if let bundleID = value(after: "--render-live"),
           let path = value(after: "--render-live", offset: 2) {
            finish(PreviewRenderer.renderLive(
                bundleIdentifier: bundleID,
                to: path,
                dark: dark,
                iconStrip: arguments.contains("--strip")
            ))
        }

        if let path = value(after: "--render-preview") {
            finish(PreviewRenderer.render(to: path, dark: dark))
        }

        if let path = value(after: "--render-strip") {
            finish(PreviewRenderer.renderStrip(to: path, dark: dark))
        }

        if let path = value(after: "--render-settings") {
            finish(PreviewRenderer.renderSettings(
                to: path, dark: dark, advanced: arguments.contains("--advanced")
            ))
        }

        if arguments.contains("--probe-vivaldi-live") {
            let path = value(after: "--probe-vivaldi-live")
                ?? NSTemporaryDirectory() + "panerail-vivaldi-live.txt"
            VivaldiProbe.live(reportPath: path)
            exit(0)
        }

        return false
    }

    private static func finish(_ succeeded: Bool) -> Never {
        NSApp.terminate(nil)
        exit(succeeded ? 0 : 1)
    }
}
