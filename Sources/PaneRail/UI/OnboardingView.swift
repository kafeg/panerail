import PaneRailKit
import SwiftUI

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
