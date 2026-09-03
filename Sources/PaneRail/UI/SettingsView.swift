import PaneRailKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var authorizer: AccessibilityAuthorizer

    var body: some View {
        TabView {
            GeneralSettingsView(preferences: preferences, authorizer: authorizer)
                .tabItem { Label("General", systemImage: "gearshape") }

            AppsSettingsView(preferences: preferences)
                .tabItem { Label("Apps", systemImage: "square.grid.2x2") }
        }
        .padding(14)
        .frame(width: 500, height: 420)
    }
}

/// The permission state is the first thing the window says, because without it
/// nothing else in here has any effect.
struct PermissionBanner: View {
    @ObservedObject var authorizer: AccessibilityAuthorizer

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: authorizer.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(authorizer.isTrusted ? Color.green : Color.orange)

            VStack(alignment: .leading, spacing: 1) {
                Text(authorizer.isTrusted ? "Accessibility access granted" : "Accessibility access required")
                    .font(.callout.weight(.semibold))
                Text(authorizer.isTrusted
                     ? "PaneRail can read and switch windows."
                     : "Until it is granted, the rail has nothing to show.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if !authorizer.isTrusted {
                Button("Open Settings…") { AccessibilityAuthorizer.openSystemSettings() }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill((authorizer.isTrusted ? Color.green : Color.orange).opacity(0.12))
        )
    }
}

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
                    Toggle("Show the rail", isOn: $preferences.isEnabled)
                }

                GridRow {
                    label("Show for")
                    Picker("", selection: $preferences.mode) {
                        Text("All applications").tag(RailMode.allApps)
                        Text("Only selected applications").tag(RailMode.listedApps)
                    }
                    .labelsHidden()
                    .frame(width: 230, alignment: .leading)
                }

                GridRow {
                    label("Appear from")
                    VStack(alignment: .leading, spacing: 2) {
                        Stepper(value: $preferences.minimumWindows, in: 1...9) {
                            Text("\(preferences.minimumWindows) window\(preferences.minimumWindows == 1 ? "" : "s")")
                        }
                        .frame(width: 130, alignment: .leading)
                        Text(preferences.minimumWindows == 1
                             ? "Shown even for single-window apps."
                             : "Apps with fewer windows are skipped.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                GridRow {
                    label("App states")
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Prefer an app's own states", isOn: $preferences.appSpecificProviders)
                        Text("Vivaldi shows its workspaces instead of windows.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                GridRow {
                    label("Width")
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
                }

                GridRow {
                    label("Position")
                    VStack(alignment: .leading, spacing: 2) {
                        Button("Reset to right edge") { preferences.resetPosition() }
                        Text("Drag the rail by its header to move it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

    private func label(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(width: labelWidth, alignment: .trailing)
    }
}

struct AppsSettingsView: View {
    @ObservedObject var preferences: Preferences
    @State private var apps: [AppDescriptor] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preferences.mode == .listedApps
                 ? "The rail appears only for the applications ticked below."
                 : "The rail currently appears for every application. Switch to “Only selected applications” in General to use this list.")
                .font(.callout)
                .foregroundStyle(preferences.mode == .listedApps ? Color.primary : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List {
                ForEach(apps) { app in
                    Toggle(isOn: binding(for: app)) {
                        HStack(spacing: 8) {
                            if let icon = app.icon {
                                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                            }
                            Text(app.name)
                            Spacer()
                            Text(app.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .disabled(preferences.mode != .listedApps)

            HStack {
                Button("Refresh") { reload() }
                Spacer()
                Text(selectionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: reload)
    }

    private var selectionSummary: String {
        let count = preferences.listedBundleIDs.count
        return "\(count) app\(count == 1 ? "" : "s") selected"
    }

    private func binding(for app: AppDescriptor) -> Binding<Bool> {
        Binding(
            get: { preferences.isListed(app.bundleIdentifier) },
            set: { _ in preferences.toggleListed(app.bundleIdentifier) }
        )
    }

    /// Selected apps that are not running right now still have to appear, or the
    /// user could never untick them.
    private func reload() {
        let running = RunningApps.userVisible()
        let listedOnly = preferences.listedBundleIDs
            .filter { id in !running.contains { $0.bundleIdentifier == id } }
            .compactMap(RunningApps.descriptor(forBundleIdentifier:))
        apps = RunningApps.dedupedSorted(running + listedOnly)
    }
}

struct OnboardingView: View {
    /// Triggering the system alert is left to the caller so that this window
    /// can step aside at the same moment: two competing permission dialogs on
    /// screen is how a stale one gets left behind for the user to mis-click.
    let onRequestAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "macwindow.on.rectangle")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("PaneRail needs Accessibility access")
                        .font(.title3.weight(.semibold))
                    Text("It is the only way macOS lets an app read and switch another app's windows.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("Open System Settings › Privacy & Security › Accessibility", systemImage: "1.circle.fill")
                Label("Turn on PaneRail in the list", systemImage: "2.circle.fill")
                Label("The rail appears by itself — no restart needed", systemImage: "3.circle.fill")
            }
            .font(.callout)

            // The grant is bound to the app's code signature, so an update
            // silently invalidates it while the switch still reads as on.
            // Without this hint that looks exactly like a broken app.
            Text("Already switched on but still seeing this? macOS ties the permission to the app's signature, so an update invalidates it. Select PaneRail in the list, remove it with \u{2212}, then add it back.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("PaneRail reads window titles only. It never records the screen and sends nothing anywhere.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack {
                Spacer()
                Button("Open System Settings", action: onRequestAccess)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460, height: 360)
    }
}
