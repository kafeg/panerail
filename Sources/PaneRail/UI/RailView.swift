import PaneRailKit
import SwiftUI

struct RailView: View {
    @ObservedObject var coordinator: RailCoordinator
    @ObservedObject var preferences: Preferences
    let onOpenSettings: () -> Void
    let onSelect: (WindowInfo) -> Void

    @State private var hoveredID: UInt64?
    @State private var isHoveringSettings = false

    private let cornerRadius: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            windowList
        }
        .frame(width: preferences.width)
        .background(VisualEffectView())
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 6) {
            if let icon = coordinator.app?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 14, height: 14)
            }

            Text(coordinator.app?.name ?? "")
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 4)

            // A tap gesture rather than a `Button`: the panel never becomes
            // key, and plain taps are the one interaction that is certain to
            // land in a non-activating window.
            Image(systemName: "gearshape.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.secondary)
                .opacity(isHoveringSettings ? 1 : 0.65)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
                .onHover { isHoveringSettings = $0 }
                .onTapGesture(perform: onOpenSettings)
                .help("PaneRail settings")
        }
        .padding(.horizontal, 8)
        .frame(height: RailGeometry.headerHeight)
        .background(WindowDragHandle())
    }

    private var windowList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(coordinator.windows) { window in
                    row(for: window)
                }
            }
        }
        .padding(.vertical, RailGeometry.verticalPadding)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func row(for window: WindowInfo) -> some View {
        let isHovered = hoveredID == window.id

        return HStack(spacing: 7) {
            Circle()
                .fill(window.isFocused ? Color.accentColor : Color.secondary.opacity(0.4))
                .frame(width: 5, height: 5)

            Text(window.title)
                .font(.system(size: 11.5))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(window.isMinimized ? Color.secondary : Color.primary)

            Spacer(minLength: 0)

            if window.isMinimized {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: RailGeometry.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                hoveredID = window.id
            } else if hoveredID == window.id {
                hoveredID = nil
            }
        }
        .onTapGesture { onSelect(window) }
        .help(window.title)
    }
}
