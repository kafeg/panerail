import PaneRailKit
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var authorizer: AccessibilityAuthorizer

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginFailed = false

    private let labelWidth: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PermissionBanner(authorizer: authorizer)

            // A hand-built grid rather than a Form: grouped forms insert an
            // empty label column for every caption, which left the window full
            // of blank cells and pushed the important rows out of sight.
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 12) {
                GridRow {
                    label("Rail")
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Show the rail", isOn: $preferences.isEnabled)
                        hint("Turns the rail off without quitting PaneRail.")
                    }
                }

                GridRow {
                    label("Show for")
                    VStack(alignment: .leading, spacing: 2) {
                        Picker("", selection: $preferences.mode) {
                            Text("All applications").tag(RailMode.allApps)
                            Text("Only selected applications").tag(RailMode.listedApps)
                            Text("All except selected").tag(RailMode.exceptListedApps)
                        }
                        .labelsHidden()
                        .frame(width: 230, alignment: .leading)
                        hint(modeHint)
                    }
                }

                GridRow {
                    label("Appear from")
                    VStack(alignment: .leading, spacing: 2) {
                        Stepper(value: $preferences.minimumWindows, in: 1...9) {
                            Text("\(preferences.minimumWindows) window\(preferences.minimumWindows == 1 ? "" : "s")")
                        }
                        .frame(width: 130, alignment: .leading)
                        hint(preferences.minimumWindows == 1
                             ? "Shown even for single-window apps."
                             : "Apps with fewer windows are skipped.")
                    }
                }

                GridRow {
                    label("Full screen")
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Hide while a window fills the screen", isOn: $preferences.hidesInFullScreen)
                        hint("Keeps the rail out of video and presentations.")
                    }
                }

                GridRow {
                    label("Width")
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Slider(
                                value: $preferences.width,
                                in: Preferences.minimumWidth...Preferences.maximumWidth
                            )
                            .frame(width: 190)
                            Text("\(Int(preferences.width)) pt")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        hint("Applies to the list; a row of icons sizes itself.")
                    }
                }

                GridRow {
                    label("Position")
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("", selection: $preferences.positionMode) {
                            Text("The same everywhere").tag(RailPositionMode.shared)
                            Text("Remembered per application").tag(RailPositionMode.perApp)
                        }
                        .labelsHidden()
                        .frame(width: 230, alignment: .leading)

                        HStack(spacing: 8) {
                            Button("Reset") { preferences.resetPositions() }
                            hint("Drag the rail by its handle to move it.")
                        }
                        hint(positionHint)
                    }
                }

                GridRow {
                    label("Startup")
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Launch at login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { newValue in
                                launchAtLoginFailed = !LaunchAtLogin.set(newValue)
                                if launchAtLoginFailed { launchAtLogin = LaunchAtLogin.isEnabled }
                            }
                        hint("Opens PaneRail automatically after you log in.")
                        if launchAtLoginFailed {
                            Text("macOS refused the login item — expected for unsigned builds outside /Applications.")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var modeHint: String {
        switch preferences.mode {
        case .allApps:
            return "Every application that has enough windows."
        case .listedApps:
            return "Only the applications ticked in the Apps tab."
        case .exceptListedApps:
            return "Every application except the ones ticked in the Apps tab."
        }
    }

    private var positionHint: String {
        preferences.positionMode == .perApp
            ? "Each application keeps its own spot; one you have not placed yet starts in the top right corner."
            : "One spot for everything, wherever you last dropped the rail."
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 300, alignment: .leading)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(width: labelWidth, alignment: .trailing)
    }
}
