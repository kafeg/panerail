import CoreGraphics

/// Layout arithmetic for the floating panel, kept free of AppKit so it can be
/// exercised without a window server.
public enum RailGeometry {
    public static let rowHeight: CGFloat = 28
    public static let headerHeight: CGFloat = 30
    public static let verticalPadding: CGFloat = 6
    /// The hairline between the header and the window list.
    public static let dividerHeight: CGFloat = 1
    public static let maxVisibleRows = 12
    /// Gap between the rail and the screen edge in the default placement.
    public static let screenMargin: CGFloat = 24

    /// Long window lists scroll rather than growing a panel taller than the screen.
    public static func visibleRowCount(for windowCount: Int, maxRows: Int = maxVisibleRows) -> Int {
        guard windowCount > 0 else { return 0 }
        return min(windowCount, max(1, maxRows))
    }

    public static func panelSize(
        windowCount: Int,
        width: CGFloat,
        maxRows: Int = maxVisibleRows
    ) -> CGSize {
        let rows = visibleRowCount(for: windowCount, maxRows: maxRows)
        let height = headerHeight + dividerHeight + CGFloat(rows) * rowHeight + verticalPadding * 2
        return CGSize(width: width, height: height)
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

    /// First-run placement: right edge, vertically centred.
    public static func defaultOrigin(size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        let origin = CGPoint(
            x: visibleFrame.maxX - size.width - screenMargin,
            y: visibleFrame.midY - size.height / 2
        )
        return clamp(origin: origin, size: size, into: visibleFrame)
    }
}
