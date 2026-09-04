import PaneRailKit
import SwiftUI

struct RailView: View {
    @ObservedObject var coordinator: RailCoordinator
    @ObservedObject var preferences: Preferences
    let onOpenSettings: () -> Void
    let onSelect: (RailItem) -> Void

    @State private var hoveredID: UInt64?
    @State private var isHoveringSettings = false
    @State private var isHoveringGrip = false

    private let cornerRadius: CGFloat = 10

    var body: some View {
        Group {
            if coordinator.layout == .iconStrip {
                iconStrip
            } else {
                VStack(spacing: 0) {
                    header
                    Divider().opacity(0.4)
                    windowList
                }
                .frame(width: preferences.width)
            }
        }
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

    /// The handle for the horizontal layout, which has no header to grab.
    ///
    /// The drag surface sits *above* the dots rather than behind them: a
    /// SwiftUI view with a content shape swallows the mouse-down, so a handle
    /// placed in the background never sees the click that would start the drag.
    private var stripGrip: some View {
        ZStack {
            // Drawn rather than an SF Symbol: the obvious symbol names for a
            // grip do not all exist, and a missing one renders as nothing.
            HStack(spacing: 3) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle().frame(width: 2, height: 2)
                        }
                    }
                }
            }
            .foregroundStyle(Color.secondary)
            .opacity(isHoveringGrip ? 0.95 : 0.5)

            WindowDragHandle()
        }
        .frame(width: RailGeometry.stripLeading, height: RailGeometry.stripHeight)
        .onHover { isHoveringGrip = $0 }
        .help("Drag to move")
    }

    /// The horizontal layout: glyphs only, with the name in a tooltip.
    private var iconStrip: some View {
        HStack(spacing: 0) {
            stripGrip

            ForEach(coordinator.items) { item in
                stripCell(for: item)
            }

            Image(systemName: "gearshape.fill")
                .font(.system(size: 9))
                .foregroundStyle(Color.secondary)
                .opacity(isHoveringSettings ? 1 : 0.6)
                .frame(width: RailGeometry.stripTrailing, height: RailGeometry.stripHeight)
                .contentShape(Rectangle())
                .onHover { isHoveringSettings = $0 }
                .onTapGesture(perform: onOpenSettings)
                .help("PaneRail settings")
        }
        .padding(.horizontal, RailGeometry.stripPadding)
        .frame(height: RailGeometry.stripHeight)
        .background(WindowDragHandle())
    }

    private func stripCell(for item: RailItem) -> some View {
        let isHovered = hoveredID == item.id

        return marker(for: item, side: 15)
            .frame(width: RailGeometry.stripItemSide, height: RailGeometry.stripHeight)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.12) : Color.clear)
                    .padding(2)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    hoveredID = item.id
                } else if hoveredID == item.id {
                    hoveredID = nil
                }
            }
            .onTapGesture { onSelect(item) }
            // Only ever seen while PaneRail happens to be the active app,
            // such as when its settings window is open: macOS does not draw
            // tooltips for an inactive one, and the rail is inactive by design.
            .help(item.title)
    }

    /// One column width for every row, so titles line up whether the provider
    /// supplies glyphs or only the plain marker.
    private var markerWidth: CGFloat {
        coordinator.items.contains { $0.iconSVG != nil } ? 14 : 5
    }

    private var windowList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(coordinator.items) { item in
                    row(for: item)
                }
            }
        }
        .padding(.vertical, RailGeometry.verticalPadding)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func marker(for item: RailItem, side: CGFloat = 13) -> some View {
        if let svg = item.iconSVG, let icon = SVGIconRenderer.shared.image(svg: svg, side: side) {
            Image(nsImage: icon)
                .renderingMode(.template)
                .foregroundStyle(item.isActive ? Color.accentColor : Color.secondary)
        } else {
            // A row with no glyph still has to be identifiable in the strip,
            // so it falls back to the first letter of its name.
            Text(item.title.prefix(1).uppercased())
                .font(.system(size: side * 0.72, weight: .medium))
                .foregroundStyle(item.isActive ? Color.accentColor : Color.secondary)
        }
    }

    @ViewBuilder
    private func listMarker(for item: RailItem) -> some View {
        if item.iconSVG != nil {
            marker(for: item)
        } else {
            Circle()
                .fill(item.isActive ? Color.accentColor : Color.secondary.opacity(0.4))
                .frame(width: 5, height: 5)
        }
    }

    private func row(for item: RailItem) -> some View {
        let isHovered = hoveredID == item.id

        return HStack(spacing: 7) {
            listMarker(for: item)
                .frame(width: markerWidth, height: 14)

            Text(item.title)
                .font(.system(size: 11.5))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(item.isDimmed ? Color.secondary : Color.primary)

            Spacer(minLength: 0)

            if item.isDimmed {
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
                hoveredID = item.id
            } else if hoveredID == item.id {
                hoveredID = nil
            }
        }
        .onTapGesture { onSelect(item) }
        .help(item.title)
    }
}
