import PaneRailKit
import SwiftUI

struct RailView: View {
    @ObservedObject var coordinator: RailCoordinator
    @ObservedObject var preferences: Preferences
    let onOpenSettings: () -> Void
    let onSelect: (RailItem) -> Void

    @State private var hoveredID: RailItemID?
    @State private var isHoveringSettings = false

    private let cornerRadius: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            content
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

    private var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(coordinator.sections.enumerated()), id: \.element.id) { index, section in
                    if index > 0 {
                        Divider().opacity(0.35).padding(.vertical, 2)
                    }
                    sectionView(section)
                }
            }
        }
        .padding(.vertical, RailGeometry.verticalPadding)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func sectionView(_ section: RailSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsSectionTitles {
                Text(section.title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: RailGeometry.sectionTitleHeight, alignment: .leading)
            }

            switch section.layout {
            case .list:
                ForEach(section.items) { row(for: $0, in: section) }
            case .glyphs:
                glyphRows(of: section)
            }
        }
    }

    private var showsSectionTitles: Bool {
        RailGeometry.showsSectionTitles(coordinator.sections)
    }

    // MARK: - Glyph sections

    /// Columns are computed the same way `RailGeometry` computes them, so the
    /// panel's height and what is drawn into it cannot disagree.
    private var glyphColumns: Int {
        let available = max(
            CGFloat(preferences.width) - RailGeometry.contentHorizontalPadding * 2,
            RailGeometry.glyphCellSide
        )
        return max(1, Int(available / RailGeometry.glyphCellSide))
    }

    private func glyphRows(of section: RailSection) -> some View {
        let columns = glyphColumns
        let rows = stride(from: 0, to: section.items.count, by: columns).map { start in
            Array(section.items[start..<min(start + columns, section.items.count)])
        }

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, items in
                HStack(spacing: 0) {
                    ForEach(items) { glyphCell(for: $0) }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, RailGeometry.contentHorizontalPadding)
    }

    private func glyphCell(for item: RailItem) -> some View {
        let isHovered = hoveredID == item.id

        return marker(for: item, side: 15)
            .frame(width: RailGeometry.glyphCellSide, height: RailGeometry.glyphCellSide)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.12) : Color.clear)
                    .padding(2)
            )
            .contentShape(Rectangle())
            .onHover { hovering in setHover(hovering, item) }
            .onTapGesture { onSelect(item) }
            // Only ever seen while PaneRail happens to be the active app, such
            // as when its settings window is open: macOS does not draw tooltips
            // for an inactive one, and the rail is inactive by design.
            .help(item.title)
    }

    // MARK: - List sections

    /// One column width for every row in a section, so titles line up whether
    /// or not its provider supplies glyphs.
    private func markerWidth(in section: RailSection) -> CGFloat {
        section.items.contains { $0.iconSVG != nil } ? 14 : 5
    }

    private func row(for item: RailItem, in section: RailSection) -> some View {
        let isHovered = hoveredID == item.id

        return HStack(spacing: 7) {
            listMarker(for: item)
                .frame(width: markerWidth(in: section), height: 14)

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
        .onHover { hovering in setHover(hovering, item) }
        .onTapGesture { onSelect(item) }
        .help(item.title)
    }

    // MARK: - Shared

    private func setHover(_ hovering: Bool, _ item: RailItem) {
        if hovering {
            hoveredID = item.id
        } else if hoveredID == item.id {
            hoveredID = nil
        }
    }

    @ViewBuilder
    private func marker(for item: RailItem, side: CGFloat = 13) -> some View {
        if let svg = item.iconSVG, let icon = SVGIconRenderer.shared.image(svg: svg, side: side) {
            Image(nsImage: icon)
                .renderingMode(.template)
                .foregroundStyle(item.isActive ? Color.accentColor : Color.secondary)
        } else {
            // A row with no glyph still has to be identifiable, so it falls
            // back to the first letter of its name.
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
}
