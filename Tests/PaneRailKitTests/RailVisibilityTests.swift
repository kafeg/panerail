import XCTest
@testable import PaneRailKit

final class RailVisibilityTests: XCTestCase {
    private func input(
        isEnabled: Bool = true,
        isTrusted: Bool = true,
        bundleID: String? = "com.example.editor",
        itemCount: Int = 3,
        mode: RailMode = .allApps,
        minimumItems: Int = 2,
        listed: Set<String> = [],
        isFullScreen: Bool = false,
        hidesInFullScreen: Bool = true
    ) -> RailVisibilityInput {
        RailVisibilityInput(
            isEnabled: isEnabled,
            isAccessibilityTrusted: isTrusted,
            bundleIdentifier: bundleID,
            itemCount: itemCount,
            mode: mode,
            minimumItems: minimumItems,
            listedBundleIDs: listed,
            isFullScreen: isFullScreen,
            hidesInFullScreen: hidesInFullScreen
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
        XCTAssertFalse(RailVisibility.shouldShow(input(itemCount: 1, minimumItems: 2)))
        XCTAssertTrue(RailVisibility.shouldShow(input(itemCount: 2, minimumItems: 2)))
    }

    func testSingleWindowModeStillNeedsAWindow() {
        XCTAssertTrue(RailVisibility.shouldShow(input(itemCount: 1, minimumItems: 1)))
        XCTAssertFalse(RailVisibility.shouldShow(input(itemCount: 0, minimumItems: 1)))
    }

    /// A stored zero or negative threshold must not turn into "show for apps
    /// with no windows at all".
    func testThresholdBelowOneIsTreatedAsOne() {
        XCTAssertFalse(RailVisibility.shouldShow(input(itemCount: 0, minimumItems: 0)))
        XCTAssertTrue(RailVisibility.shouldShow(input(itemCount: 1, minimumItems: -5)))
    }

    func testListedModeOnlyShowsSelectedApps() {
        let listed: Set<String> = ["com.example.editor"]
        XCTAssertTrue(RailVisibility.shouldShow(input(mode: .listedApps, listed: listed)))
        XCTAssertFalse(RailVisibility.shouldShow(
            input(bundleID: "com.example.other", mode: .listedApps, listed: listed)
        ))
    }

    /// Eligibility is the half of the rule that does not need a row count, so a
    /// caller can skip collecting rows for an app that is ruled out anyway.
    func testHiddenWhileAWindowFillsTheScreen() {
        XCTAssertFalse(RailVisibility.shouldShow(input(isFullScreen: true)))
    }

    func testFullScreenIsIgnoredWhenTheSettingIsOff() {
        XCTAssertTrue(RailVisibility.shouldShow(input(isFullScreen: true, hidesInFullScreen: false)))
    }

    func testEligibilityIgnoresTheRowCount() {
        XCTAssertTrue(RailVisibility.isEligible(input(itemCount: 0)))
        XCTAssertFalse(RailVisibility.isEligible(input(isEnabled: false, itemCount: 99)))
        XCTAssertFalse(RailVisibility.isEligible(input(bundleID: "dev.kafeg.panerail", itemCount: 99)))
        XCTAssertFalse(RailVisibility.isEligible(
            input(itemCount: 99, mode: .listedApps, listed: ["com.example.other"])
        ))
        XCTAssertTrue(RailVisibility.isEligible(
            input(itemCount: 0, mode: .listedApps, listed: ["com.example.editor"])
        ))
    }

    func testListedModeStillRespectsThreshold() {
        XCTAssertFalse(RailVisibility.shouldShow(
            input(itemCount: 1, mode: .listedApps, minimumItems: 2, listed: ["com.example.editor"])
        ))
    }
}
