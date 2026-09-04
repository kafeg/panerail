import XCTest
@testable import PaneRailKit

final class RailVisibilityTests: XCTestCase {
    private func input(
        isEnabled: Bool = true,
        isTrusted: Bool = true,
        bundleID: String? = "com.example.editor",
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
            mode: mode,
            minimumItems: minimumItems,
            listedBundleIDs: listed,
            isFullScreen: isFullScreen,
            hidesInFullScreen: hidesInFullScreen
        )
    }

    // MARK: - Eligibility

    func testShowsForAnOrdinaryApp() {
        XCTAssertTrue(RailVisibility.shouldShow(input(), itemCount: 3))
    }

    func testHiddenWhenDisabled() {
        XCTAssertFalse(RailVisibility.isEligible(input(isEnabled: false)))
    }

    func testHiddenWithoutAccessibilityPermission() {
        XCTAssertFalse(RailVisibility.isEligible(input(isTrusted: false)))
    }

    func testHiddenWithoutBundleIdentifier() {
        XCTAssertFalse(RailVisibility.isEligible(input(bundleID: nil)))
        XCTAssertFalse(RailVisibility.isEligible(input(bundleID: "")))
    }

    func testHiddenForOwnApp() {
        XCTAssertFalse(RailVisibility.isEligible(input(bundleID: "dev.kafeg.panerail")))
    }

    func testHiddenForSystemShells() {
        for bundleID in ["com.apple.loginwindow", "com.apple.WindowManager"] {
            XCTAssertFalse(RailVisibility.isEligible(input(bundleID: bundleID)), bundleID)
        }
    }

    func testHiddenWhileAWindowFillsTheScreen() {
        XCTAssertFalse(RailVisibility.isEligible(input(isFullScreen: true)))
    }

    func testFullScreenIsIgnoredWhenTheSettingIsOff() {
        XCTAssertTrue(RailVisibility.isEligible(input(isFullScreen: true, hidesInFullScreen: false)))
    }

    /// Eligibility deliberately says nothing about how many rows there are, so
    /// a caller can rule an app out before doing the work of collecting them.
    func testEligibilityDoesNotDependOnTheRowCount() {
        XCTAssertTrue(RailVisibility.isEligible(input()))
        XCTAssertFalse(RailVisibility.shouldShow(input(), itemCount: 0))
    }

    // MARK: - Which apps

    func testListedModeShowsOnlyTheTickedApps() {
        let listed: Set<String> = ["com.example.editor"]
        XCTAssertTrue(RailVisibility.isEligible(input(mode: .listedApps, listed: listed)))
        XCTAssertFalse(RailVisibility.isEligible(
            input(bundleID: "com.example.other", mode: .listedApps, listed: listed)
        ))
    }

    func testExceptListedModeHidesOnlyTheTickedApps() {
        let listed: Set<String> = ["com.example.editor"]
        XCTAssertFalse(RailVisibility.isEligible(input(mode: .exceptListedApps, listed: listed)))
        XCTAssertTrue(RailVisibility.isEligible(
            input(bundleID: "com.example.other", mode: .exceptListedApps, listed: listed)
        ))
    }

    /// The exclusions apply whichever way round the list is being read.
    func testExceptListedModeStillHidesOurOwnApp() {
        XCTAssertFalse(RailVisibility.isEligible(
            input(bundleID: "dev.kafeg.panerail", mode: .exceptListedApps)
        ))
    }

    // MARK: - Threshold

    func testThreshold() {
        XCTAssertFalse(RailVisibility.meetsThreshold(itemCount: 1, minimumItems: 2))
        XCTAssertTrue(RailVisibility.meetsThreshold(itemCount: 2, minimumItems: 2))
        XCTAssertTrue(RailVisibility.meetsThreshold(itemCount: 5, minimumItems: 2))
    }

    func testSingleItemModeStillNeedsAnItem() {
        XCTAssertTrue(RailVisibility.meetsThreshold(itemCount: 1, minimumItems: 1))
        XCTAssertFalse(RailVisibility.meetsThreshold(itemCount: 0, minimumItems: 1))
    }

    /// A stored zero or negative threshold must not turn into "show for an app
    /// with nothing to switch between".
    func testThresholdBelowOneIsTreatedAsOne() {
        XCTAssertFalse(RailVisibility.meetsThreshold(itemCount: 0, minimumItems: 0))
        XCTAssertTrue(RailVisibility.meetsThreshold(itemCount: 1, minimumItems: -5))
    }

    func testBothHalvesMustAgree() {
        let listed: Set<String> = ["com.example.editor"]
        XCTAssertFalse(
            RailVisibility.shouldShow(input(mode: .listedApps, minimumItems: 2, listed: listed), itemCount: 1),
            "listed, but not enough rows"
        )
        XCTAssertFalse(
            RailVisibility.shouldShow(input(bundleID: "com.example.other", mode: .listedApps, listed: listed), itemCount: 9),
            "plenty of rows, but not listed"
        )
    }
}
