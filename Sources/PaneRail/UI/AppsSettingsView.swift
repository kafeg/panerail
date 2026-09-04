import PaneRailKit
import SwiftUI

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
