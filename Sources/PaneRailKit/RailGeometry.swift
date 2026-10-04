import CoreGraphics
import Foundation

/// Layout arithmetic for the floating panels, kept free of AppKit so it can be
/// exercised without a window server.
///
/// Each panel shows one section, so sizing is per section rather than per rail.
public enum RailGeometry {
    public static let rowHeight: CGFloat = 28
    public static let headerHeight: CGFloat = 30
    public static let verticalPadding: CGFloat = 6
    /// The hairline between the header and the rows.
    public static let dividerHeight: CGFloat = 1
    public static let maxVisibleRows = 12
    /// Gap between a panel and the screen edge in the default placement.
    public static let screenMargin: CGFloat = 24

    // The glyph panel: one square per row, plus room for the grip and the gear.
    public static let glyphCellSide: CGFloat = 26
    public static let glyphPanelHeight: CGFloat = 32
    public static let glyphPanelPadding: CGFloat = 5
    /// The grip. Without one the panel has nowhere to grab: glyphs and the gear
    /// take every click across the rest of it.
    public static let glyphPanelLeading: CGFloat = 16
    public static let glyphPanelTrailing: CGFloat = 22
    public static let maxVisibleGlyphs = 16

    /// Long lists scroll rather than growing a panel taller than the screen.
    public static func visibleRowCount(for itemCount: Int, maxRows: Int = maxVisibleRows) -> Int {
        guard itemCount > 0 else { return 0 }
        return min(itemCount, max(1, maxRows))
    }

    public static func listSize(
        itemCount: Int,
        width: CGFloat,
        maxRows: Int = maxVisibleRows
    ) -> CGSize {
        let rows = visibleRowCount(for: itemCount, maxRows: maxRows)
        let height = headerHeight + dividerHeight + CGFloat(rows) * rowHeight + verticalPadding * 2
        return CGSize(width: width, height: height)
    }

    /// The glyph panel grows sideways instead of downwards, so it needs its own
    /// arithmetic rather than a transposed list.
    public static func glyphPanelSize(itemCount: Int, maxItems: Int = maxVisibleGlyphs) -> CGSize {
        let shown = min(max(itemCount, 0), max(1, maxItems))
        let width = glyphPanelPadding * 2
            + glyphPanelLeading
            + CGFloat(shown) * glyphCellSide
            + glyphPanelTrailing
        return CGSize(width: width, height: glyphPanelHeight)
    }

    public static func size(for section: RailSection, width: CGFloat) -> CGSize {
        switch section.layout {
        case .list:
            return listSize(itemCount: section.items.count, width: width)
        case .glyphs:
            return glyphPanelSize(itemCount: section.items.count)
        }
    }

    /// Keeps a panel fully on screen. One larger than the visible frame is
    /// pinned to the origin corner rather than centred, so its handle stays
    /// reachable.
    public static func clamp(origin: CGPoint, size: CGSize, into visibleFrame: CGRect) -> CGPoint {
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - size.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - size.height)
        return CGPoint(
            x: min(max(origin.x, visibleFrame.minX), maxX),
            y: min(max(origin.y, visibleFrame.minY), maxY)
        )
    }

    /// Placement for a panel that has not been positioned yet: the top right
    /// corner, clear of the menu bar.
    ///
    /// A second panel is offset below the first so the two do not open on top
    /// of each other.
    public static func defaultOrigin(
        size: CGSize,
        in visibleFrame: CGRect,
        stackedBelow: CGFloat = 0
    ) -> CGPoint {
        let origin = CGPoint(
            x: visibleFrame.maxX - size.width - screenMargin,
            y: visibleFrame.maxY - size.height - screenMargin - stackedBelow
        )
        return clamp(origin: origin, size: size, into: visibleFrame)
    }
}
