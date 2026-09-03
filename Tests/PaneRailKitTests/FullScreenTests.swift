import XCTest
@testable import PaneRailKit

final class FullScreenGeometryTests: XCTestCase {
    private let screen = CGSize(width: 1440, height: 900)

    func testAWindowFillingTheDisplayCounts() {
        XCTAssertTrue(FullScreenGeometry.covers(windowSize: screen, screenSize: screen))
    }

    /// A zoomed window stops below the menu bar, which is what separates it
    /// from full screen — the rail should stay visible for it.
    func testAZoomedWindowDoesNot() {
        let zoomed = CGSize(width: 1440, height: 900 - 37)
        XCTAssertFalse(FullScreenGeometry.covers(windowSize: zoomed, screenSize: screen))
    }

    func testASmallWindowDoesNot() {
        XCTAssertFalse(FullScreenGeometry.covers(windowSize: CGSize(width: 800, height: 600), screenSize: screen))
    }

    /// Rounding in the accessibility API should not decide the answer.
    func testToleratesSubPixelRounding() {
        let almost = CGSize(width: 1439, height: 899)
        XCTAssertTrue(FullScreenGeometry.covers(windowSize: almost, screenSize: screen))
    }

    func testAnEmptyScreenIsNeverCovered() {
        XCTAssertFalse(FullScreenGeometry.covers(windowSize: screen, screenSize: .zero))
    }
}
