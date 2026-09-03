import XCTest
@testable import PaneRailKit

final class RailVisibilityTests: XCTestCase {
    private func input(
        isEnabled: Bool = true,
        isTrusted: Bool = true,
        bundleID: String? = "com.example.editor",
        windowCount: Int = 3,
        mode: RailMode = .allApps,
        minimumWindows: Int = 2,
        listed: Set<String> = []
    ) -> RailVisibilityInput {
        RailVisibilityInput(
            isEnabled: isEnabled,
            isAccessibilityTrusted: isTrusted,
            bundleIdentifier: bundleID,
            windowCount: windowCount,
            mode: mode,
            minimumWindows: minimumWindows,
            listedBundleIDs: listed
        )
    }

    func testShowsForOrdinaryAppAboveThreshold() {
        XCTAssertTrue(RailVisibility.shouldShow(input()))
    }

    func testHiddenWhenDisabled() {
        XCTAssertFalse(RailVisibility.shouldShow(input(isEnabled: false)))
    }

    func testHiddenWithoutAccessibilityPermission() {
        XCTAssertFalse(RailVisibility.shouldShow(input(isTrusted: false)))
    }

    func testHiddenWithoutBundleIdentifier() {
        XCTAssertFalse(RailVisibility.shouldShow(input(bundleID: nil)))
        XCTAssertFalse(RailVisibility.shouldShow(input(bundleID: "")))
    }

    func testHiddenForOwnApp() {
        XCTAssertFalse(RailVisibility.shouldShow(input(bundleID: "dev.kafeg.panerail")))
    }

    func testHiddenForSystemShells() {
        for bundleID in ["com.apple.loginwindow", "com.apple.WindowManager"] {
            XCTAssertFalse(RailVisibility.shouldShow(input(bundleID: bundleID)), bundleID)
        }
    }

    func testWindowCountThreshold() {
        XCTAssertFalse(RailVisibility.shouldShow(input(windowCount: 1, minimumWindows: 2)))
        XCTAssertTrue(RailVisibility.shouldShow(input(windowCount: 2, minimumWindows: 2)))
    }

    func testSingleWindowModeStillNeedsAWindow() {
        XCTAssertTrue(RailVisibility.shouldShow(input(windowCount: 1, minimumWindows: 1)))
        XCTAssertFalse(RailVisibility.shouldShow(input(windowCount: 0, minimumWindows: 1)))
    }

    /// A stored zero or negative threshold must not turn into "show for apps
    /// with no windows at all".
    func testThresholdBelowOneIsTreatedAsOne() {
        XCTAssertFalse(RailVisibility.shouldShow(input(windowCount: 0, minimumWindows: 0)))
        XCTAssertTrue(RailVisibility.shouldShow(input(windowCount: 1, minimumWindows: -5)))
    }

    func testListedModeOnlyShowsSelectedApps() {
        let listed: Set<String> = ["com.example.editor"]
        XCTAssertTrue(RailVisibility.shouldShow(input(mode: .listedApps, listed: listed)))
        XCTAssertFalse(RailVisibility.shouldShow(
            input(bundleID: "com.example.other", mode: .listedApps, listed: listed)
        ))
    }

    func testListedModeStillRespectsThreshold() {
        XCTAssertFalse(RailVisibility.shouldShow(
            input(windowCount: 1, mode: .listedApps, minimumWindows: 2, listed: ["com.example.editor"])
        ))
    }
}
