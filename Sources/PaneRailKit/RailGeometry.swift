import CoreGraphics
import Foundation

/// Layout arithmetic for the floating panel, kept free of AppKit so it can be
/// exercised without a window server.
public enum RailGeometry {
    public static let rowHeight: CGFloat = 28
    public static let headerHeight: CGFloat = 30
    public static let verticalPadding: CGFloat = 6
    /// The hairline under the header, and between sections.
    public static let dividerHeight: CGFloat = 1
    /// Shown above a section only when the rail has more than one.
    public static let sectionTitleHeight: CGFloat = 19
    public static let maxVisibleRows = 12
    /// Gap between the rail and the screen edge in the default placement.
    public static let screenMargin: CGFloat = 24

    /// One square per glyph in a `.glyphs` section.
    public static let glyphCellSide: CGFloat = 26
    public static let contentHorizontalPadding: CGFloat = 8

    /// Long lists scroll rather than growing a panel taller than the screen.
    public static func visibleRowCount(for itemCount: Int, maxRows: Int = maxVisibleRows) -> Int {
        guard itemCount > 0 else { return 0 }
        return min(itemCount, max(1, maxRows))
    }

    /// Glyphs wrap: the panel's width is set by the list sections, so a long
    /// row of them has to fold onto a second line rather than widen the rail.
    public static func glyphRowCount(itemCount: Int, width: CGFloat) -> Int {
        guard itemCount > 0 else { return 0 }
        let available = max(width - contentHorizontalPadding * 2, glyphCellSide)
        let perRow = max(1, Int(available / glyphCellSide))
        return Int((Double(itemCount) / Double(perRow)).rounded(.up))
    }

    public static func sectionHeight(
        _ section: RailSection,
        width: CGFloat,
        showsTitle: Bool,
        maxRows: Int = maxVisibleRows
    ) -> CGFloat {
        let title = showsTitle ? sectionTitleHeight : 0

        switch section.layout {
        case .list:
            return title + CGFloat(visibleRowCount(for: section.items.count, maxRows: maxRows)) * rowHeight
        case .glyphs:
            return title + CGFloat(glyphRowCount(itemCount: section.items.count, width: width)) * glyphCellSide
        }
    }

    /// Titles earn their place only when there is more than one section to tell
    /// apart; a single-section rail must look exactly as it always did.
    public static func showsSectionTitles(_ sections: [RailSection]) -> Bool {
        sections.count > 1
    }

    public static func panelSize(
        sections: [RailSection],
        width: CGFloat,
        maxRows: Int = maxVisibleRows
    ) -> CGSize {
        let chrome = headerHeight + dividerHeight + verticalPadding * 2
        guard !sections.isEmpty else { return CGSize(width: width, height: chrome) }

        let showsTitles = showsSectionTitles(sections)
        let content = sections.reduce(CGFloat.zero) { total, section in
            total + sectionHeight(section, width: width, showsTitle: showsTitles, maxRows: maxRows)
        }
        let separators = CGFloat(sections.count - 1) * dividerHeight

        return CGSize(width: width, height: chrome + content + separators)
    }

    /// Keeps the panel fully on screen. A panel larger than the visible frame
    /// is pinned to the origin corner rather than centred, so its header stays
    /// reachable.
    public static func clamp(origin: CGPoint, size: CGSize, into visibleFrame: CGRect) -> CGPoint {
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - size.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - size.height)
        return CGPoint(
            x: min(max(origin.x, visibleFrame.minX), maxX),
            y: min(max(origin.y, visibleFrame.minY), maxY)
        )
    }

    /// Placement for an app the rail has not been positioned for: the top
    /// right corner, clear of the menu bar.
    public static func defaultOrigin(size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        let origin = CGPoint(
            x: visibleFrame.maxX - size.width - screenMargin,
            y: visibleFrame.maxY - size.height - screenMargin
        )
        return clamp(origin: origin, size: size, into: visibleFrame)
    }
}
