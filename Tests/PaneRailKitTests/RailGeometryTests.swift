import XCTest
@testable import PaneRailKit

final class RailGeometryTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 850)
    private let width: CGFloat = 255

    private func list(_ count: Int, id: String = "windows") -> RailSection {
        RailSection(
            id: id,
            title: "Windows",
            items: (0..<count).map { RailItem(id: UInt64($0), title: "w\($0)") }
        )
    }

    private func glyphs(_ count: Int, id: String = "glyphs") -> RailSection {
        RailSection(
            id: id,
            title: "Workspaces",
            layout: .glyphs,
            items: (0..<count).map { RailItem(id: UInt64($0), title: "g\($0)") }
        )
    }

    // MARK: - Panel size

    func testHeightGrowsWithRowCount() {
        let two = RailGeometry.panelSize(sections: [list(2)], width: width)
        let five = RailGeometry.panelSize(sections: [list(5)], width: width)
        XCTAssertEqual(five.height - two.height, RailGeometry.rowHeight * 3, accuracy: 0.001)
    }

    func testWidthIsPassedThrough() {
        XCTAssertEqual(RailGeometry.panelSize(sections: [list(3)], width: 260).width, 260)
    }

    /// Beyond the cap the list scrolls, so the panel must stop growing.
    func testHeightIsCappedAtMaxVisibleRows() {
        let capped = RailGeometry.panelSize(sections: [list(40)], width: width)
        let atCap = RailGeometry.panelSize(sections: [list(RailGeometry.maxVisibleRows)], width: width)
        XCTAssertEqual(capped.height, atCap.height)
    }

    func testAnEmptyRailIsJustItsChrome() {
        let size = RailGeometry.panelSize(sections: [], width: width)
        XCTAssertEqual(size.height, RailGeometry.headerHeight + RailGeometry.dividerHeight + RailGeometry.verticalPadding * 2)
    }

    // MARK: - Several sections

    func testASecondSectionAddsItsRowsATitleAndASeparator() {
        let one = RailGeometry.panelSize(sections: [list(3)], width: width)
        let two = RailGeometry.panelSize(sections: [list(3), list(2, id: "other")], width: width)

        // Two rows, a separator, and a title for each of the two sections,
        // which a single-section rail does not carry.
        let expected = RailGeometry.rowHeight * 2
            + RailGeometry.dividerHeight
            + RailGeometry.sectionTitleHeight * 2
        XCTAssertEqual(two.height - one.height, expected, accuracy: 0.001)
    }

    func testTitlesAppearOnlyWithMoreThanOneSection() {
        XCTAssertFalse(RailGeometry.showsSectionTitles([list(3)]))
        XCTAssertTrue(RailGeometry.showsSectionTitles([list(3), glyphs(4)]))
    }

    // MARK: - Glyph sections

    /// Glyphs wrap instead of widening the rail: the width belongs to the list
    /// sections, and a long row of workspaces must fold rather than overflow.
    func testGlyphsWrapOntoFurtherRows() {
        let perRow = Int((width - RailGeometry.contentHorizontalPadding * 2) / RailGeometry.glyphCellSide)
        XCTAssertGreaterThan(perRow, 1, "the fixture would not exercise wrapping otherwise")

        XCTAssertEqual(RailGeometry.glyphRowCount(itemCount: perRow, width: width), 1)
        XCTAssertEqual(RailGeometry.glyphRowCount(itemCount: perRow + 1, width: width), 2)
        XCTAssertEqual(RailGeometry.glyphRowCount(itemCount: 0, width: width), 0)
    }

    func testANarrowRailStillFitsOneGlyphPerRow() {
        XCTAssertEqual(RailGeometry.glyphRowCount(itemCount: 3, width: 10), 3)
    }

    func testAGlyphSectionIsMeasuredInGlyphRows() {
        let section = glyphs(3)
        let height = RailGeometry.sectionHeight(section, width: width, showsTitle: false)
        XCTAssertEqual(height, RailGeometry.glyphCellSide, accuracy: 0.001)
    }

    func testClampLeavesOnScreenOriginAlone() {
        let size = CGSize(width: 220, height: 200)
        let origin = CGPoint(x: 400, y: 300)
        XCTAssertEqual(RailGeometry.clamp(origin: origin, size: size, into: screen), origin)
    }

    func testClampPullsBackOffScreenOrigin() {
        let size = CGSize(width: 220, height: 200)

        let pastRight = RailGeometry.clamp(origin: CGPoint(x: 1400, y: 300), size: size, into: screen)
        XCTAssertEqual(pastRight.x, screen.maxX - size.width)

        let pastTop = RailGeometry.clamp(origin: CGPoint(x: 400, y: 800), size: size, into: screen)
        XCTAssertEqual(pastTop.y, screen.maxY - size.height)

        let negative = RailGeometry.clamp(origin: CGPoint(x: -50, y: -80), size: size, into: screen)
        XCTAssertEqual(negative, CGPoint(x: screen.minX, y: screen.minY))
    }

    /// A rail taller than the screen is pinned to the bottom-left so its header
    /// stays reachable instead of being pushed above the top edge.
    func testClampPinsOversizedPanelToOrigin() {
        let size = CGSize(width: 2000, height: 2000)
        let clamped = RailGeometry.clamp(origin: CGPoint(x: 500, y: 500), size: size, into: screen)
        XCTAssertEqual(clamped, CGPoint(x: screen.minX, y: screen.minY))
    }

    func testDefaultOriginSitsInTheTopRightCorner() {
        let size = CGSize(width: 220, height: 200)
        let origin = RailGeometry.defaultOrigin(size: size, in: screen)
        XCTAssertEqual(origin.x, screen.maxX - size.width - RailGeometry.screenMargin)
        XCTAssertEqual(origin.y, screen.maxY - size.height - RailGeometry.screenMargin, accuracy: 0.001)
    }

    func testDefaultOriginRespectsScreenOffset() {
        let external = CGRect(x: -1920, y: 200, width: 1920, height: 1080)
        let size = CGSize(width: 220, height: 200)
        let origin = RailGeometry.defaultOrigin(size: size, in: external)
        XCTAssertTrue(external.contains(CGRect(origin: origin, size: size)))
    }
}
