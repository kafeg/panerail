import PaneRailKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var authorizer: AccessibilityAuthorizer

    var body: some View {
        VStack(spacing: 6) {
            tabs
            // Its own row rather than an overlay, so it can never land on top
            // of a tab's content.
            Text("PaneRail \(AppVersion.display)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(width: 500, height: 545)
    }

    private var tabs: some View {
        TabView {
            GeneralSettingsView(preferences: preferences, authorizer: authorizer)
                .tabItem { Label("General", systemImage: "gearshape") }

            AppsSettingsView(preferences: preferences)
                .tabItem { Label("Apps", systemImage: "square.grid.2x2") }

            AdvancedSettingsView(preferences: preferences)
                .tabItem { Label("Advanced", systemImage: "flask") }
        }
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

struct AppsSettingsView: View {
    @ObservedObject var preferences: Preferences
    @State private var apps: [AppDescriptor] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(listPurpose)
                .font(.callout)
                .foregroundStyle(preferences.mode == .allApps ? Color.secondary : Color.primary)
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
            .disabled(preferences.mode == .allApps)

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

    /// What ticking a box in this list actually does depends on the mode
    /// chosen in General, so the list says so rather than leaving the user to
    /// remember.
    private var listPurpose: String {
        switch preferences.mode {
        case .allApps:
            return "The rail currently appears for every application. Choose “Only selected applications” or “All except selected” in General to use this list."
        case .listedApps:
            return "The rail appears only for the applications ticked below."
        case .exceptListedApps:
            return "The rail appears everywhere except the applications ticked below."
        }
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
