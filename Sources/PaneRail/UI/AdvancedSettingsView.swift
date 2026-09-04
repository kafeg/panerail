import PaneRailKit
import SwiftUI

/// Everything that depends on another application's internals lives here,
/// away from the settings that simply work.
struct AdvancedSettingsView: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("App-specific states")
                    .font(.headline)
                Text("""
                Some applications keep their own internal states that matter \
                more than their windows. The rail can show those instead.
                """)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)
            }

            Toggle("Use an app's own states", isOn: $preferences.appSpecificProviders)

            Text("""
            Off by default: this depends on internals the other application \
            does not document, and its next update may change them. Whenever \
            they cannot be read, that app falls back to plain window switching.
            """)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Supported applications")
                    .font(.headline)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "square.grid.3x3.topleft.filled")
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Vivaldi — workspaces")
                        Text("""
                        Workspaces live inside a single window, so window \
                        switching does not reach them.
                        """)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Toggle("Show as a row of icons", isOn: $preferences.vivaldiIconStrip)
                        Text("""
                        Each workspace becomes its own glyph. Names are not shown: \
                        macOS draws tooltips only for the active application, and \
                        the rail never becomes one, which is what stops it stealing \
                        focus. Falls back to the list when a workspace has no icon.
                        """)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("""
                        Only the first \(VivaldiRailProvider.switchableCount) \
                        workspaces can be switched to. Switching works by \
                        sending Vivaldi's own keyboard shortcut, and Vivaldi \
                        binds shortcuts to that many; the rest are listed but \
                        dimmed.
                        """)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .disabled(!preferences.appSpecificProviders)
                .opacity(preferences.appSpecificProviders ? 1 : 0.5)
            }

            Spacer(minLength: 0)
        }
    }
}
