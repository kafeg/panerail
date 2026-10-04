import XCTest
@testable import PaneRailKit

final class RailGeometryTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 850)
    private let width: CGFloat = 255

    private func list(_ count: Int) -> RailSection {
        RailSection(
            id: WindowRailProvider.sectionID,
            title: "Windows",
            items: (0..<count).map { RailItem(id: UInt64($0), title: "w\($0)") }
        )
    }

    private func glyphs(_ count: Int) -> RailSection {
        RailSection(
            id: "glyphs",
            title: "Workspaces",
            layout: .glyphs,
            items: (0..<count).map { RailItem(id: UInt64($0), title: "g\($0)") }
        )
    }

    // MARK: - The list panel

    func testHeightGrowsWithRowCount() {
        let two = RailGeometry.listSize(itemCount: 2, width: width)
        let five = RailGeometry.listSize(itemCount: 5, width: width)
        XCTAssertEqual(five.height - two.height, RailGeometry.rowHeight * 3, accuracy: 0.001)
    }

    func testWidthIsPassedThrough() {
        XCTAssertEqual(RailGeometry.listSize(itemCount: 3, width: 260).width, 260)
    }

    /// Beyond the cap the list scrolls, so the panel must stop growing.
    func testHeightIsCappedAtMaxVisibleRows() {
        let capped = RailGeometry.listSize(itemCount: 40, width: width)
        let atCap = RailGeometry.listSize(itemCount: RailGeometry.maxVisibleRows, width: width)
        XCTAssertEqual(capped.height, atCap.height)
    }

    func testVisibleRowCount() {
        XCTAssertEqual(RailGeometry.visibleRowCount(for: 0), 0)
        XCTAssertEqual(RailGeometry.visibleRowCount(for: 3, maxRows: 12), 3)
        XCTAssertEqual(RailGeometry.visibleRowCount(for: 30, maxRows: 12), 12)
    }

    // MARK: - The glyph panel

    func testTheGlyphPanelGrowsSidewaysAndKeepsItsHeight() {
        let three = RailGeometry.glyphPanelSize(itemCount: 3)
        let six = RailGeometry.glyphPanelSize(itemCount: 6)
        XCTAssertEqual(six.width - three.width, RailGeometry.glyphCellSide * 3, accuracy: 0.001)
        XCTAssertEqual(three.height, six.height)
        XCTAssertEqual(three.height, RailGeometry.glyphPanelHeight)
    }

    /// The grip and the gear both need room of their own, or there is nowhere
    /// left to grab the panel by.
    func testTheGlyphPanelLeavesRoomForTheGripAndTheGear() {
        XCTAssertGreaterThanOrEqual(
            RailGeometry.glyphPanelSize(itemCount: 0).width,
            RailGeometry.glyphPanelLeading + RailGeometry.glyphPanelTrailing
        )
    }

    func testTheGlyphPanelStopsGrowingAtItsCap() {
        let capped = RailGeometry.glyphPanelSize(itemCount: 200)
        let atCap = RailGeometry.glyphPanelSize(itemCount: RailGeometry.maxVisibleGlyphs)
        XCTAssertEqual(capped.width, atCap.width)
    }

    /// A panel is sized by the one section it shows.
    func testSizeFollowsTheSection() {
        XCTAssertEqual(
            RailGeometry.size(for: list(4), width: width),
            RailGeometry.listSize(itemCount: 4, width: width)
        )
        let strip = RailGeometry.size(for: glyphs(4), width: width)
        XCTAssertEqual(strip, RailGeometry.glyphPanelSize(itemCount: 4))
        XCTAssertGreaterThan(strip.width, strip.height, "the glyph panel is wider than it is tall")
    }

    // MARK: - Placement

    /// Two panels opening for the first time must not land on top of each other.
    func testASecondPanelOpensBelowTheFirst() {
        let size = CGSize(width: 220, height: 200)
        let first = RailGeometry.defaultOrigin(size: size, in: screen)
        let second = RailGeometry.defaultOrigin(size: size, in: screen, stackedBelow: 120)

        XCTAssertEqual(first.x, second.x, "both hug the same edge")
        XCTAssertEqual(first.y - second.y, 120, accuracy: 0.001)
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
