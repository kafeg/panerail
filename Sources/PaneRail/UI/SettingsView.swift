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
