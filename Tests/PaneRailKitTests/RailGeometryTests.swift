import XCTest
@testable import PaneRailKit

final class RailGeometryTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 850)

    func testHeightGrowsWithWindowCount() {
        let two = RailGeometry.panelSize(itemCount: 2, width: 220)
        let five = RailGeometry.panelSize(itemCount: 5, width: 220)
        XCTAssertEqual(five.height - two.height, RailGeometry.rowHeight * 3, accuracy: 0.001)
    }

    func testWidthIsPassedThrough() {
        XCTAssertEqual(RailGeometry.panelSize(itemCount: 3, width: 260).width, 260)
    }

    /// Beyond the cap the list scrolls, so the panel must stop growing.
    func testHeightIsCappedAtMaxVisibleRows() {
        let capped = RailGeometry.panelSize(itemCount: 40, width: 220)
        let atCap = RailGeometry.panelSize(itemCount: RailGeometry.maxVisibleRows, width: 220)
        XCTAssertEqual(capped.height, atCap.height)
    }

    func testVisibleRowCount() {
        XCTAssertEqual(RailGeometry.visibleRowCount(for: 0), 0)
        XCTAssertEqual(RailGeometry.visibleRowCount(for: 3, maxRows: 12), 3)
        XCTAssertEqual(RailGeometry.visibleRowCount(for: 30, maxRows: 12), 12)
    }

    // MARK: - Horizontal layout

    func testTheStripGrowsSidewaysAndKeepsItsHeight() {
        let three = RailGeometry.stripSize(itemCount: 3)
        let six = RailGeometry.stripSize(itemCount: 6)
        XCTAssertEqual(six.width - three.width, RailGeometry.stripItemSide * 3, accuracy: 0.001)
        XCTAssertEqual(three.height, six.height)
        XCTAssertEqual(three.height, RailGeometry.stripHeight)
    }

    func testTheStripLeavesRoomForTheGear() {
        XCTAssertGreaterThanOrEqual(
            RailGeometry.stripSize(itemCount: 0).width,
            RailGeometry.stripTrailing
        )
    }

    func testTheStripStopsGrowingAtItsCap() {
        let capped = RailGeometry.stripSize(itemCount: 200)
        let atCap = RailGeometry.stripSize(itemCount: RailGeometry.maxVisibleStripItems)
        XCTAssertEqual(capped.width, atCap.width)
    }

    func testSizeFollowsTheLayout() {
        let list = RailGeometry.size(for: .list, itemCount: 4, width: 255)
        let strip = RailGeometry.size(for: .iconStrip, itemCount: 4, width: 255)
        XCTAssertEqual(list, RailGeometry.panelSize(itemCount: 4, width: 255))
        XCTAssertEqual(strip, RailGeometry.stripSize(itemCount: 4))
        XCTAssertGreaterThan(strip.width, strip.height, "the strip is wider than it is tall")
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

    func testDefaultOriginSitsAtRightEdgeAndIsVerticallyCentred() {
        let size = CGSize(width: 220, height: 200)
        let origin = RailGeometry.defaultOrigin(size: size, in: screen)
        XCTAssertEqual(origin.x, screen.maxX - size.width - RailGeometry.screenMargin)
        XCTAssertEqual(origin.y, screen.midY - size.height / 2, accuracy: 0.001)
    }

    func testDefaultOriginRespectsScreenOffset() {
        let external = CGRect(x: -1920, y: 200, width: 1920, height: 1080)
        let size = CGSize(width: 220, height: 200)
        let origin = RailGeometry.defaultOrigin(size: size, in: external)
        XCTAssertTrue(external.contains(CGRect(origin: origin, size: size)))
    }
}
