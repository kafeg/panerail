import XCTest
@testable import PaneRailKit

final class AppVersionTests: XCTestCase {
    func testShowsTheBuildWhenItAddsSomething() {
        XCTAssertEqual(AppVersion.display(marketing: "0.2.0", build: "47"), "0.2.0 (47)")
    }

    /// A release built from a tag carries no useful build number, and "(1)"
    /// next to the version is noise.
    func testHidesAnUninformativeBuild() {
        XCTAssertEqual(AppVersion.display(marketing: "0.1.0", build: "1"), "0.1.0")
        XCTAssertEqual(AppVersion.display(marketing: "0.1.0", build: "0.1.0"), "0.1.0")
        XCTAssertEqual(AppVersion.display(marketing: "0.1.0", build: ""), "0.1.0")
    }

    /// The third component is the commit count, so "0.1.147 (147)" would say
    /// the same thing twice.
    func testHidesABuildThatIsAlreadyTheLastComponent() {
        XCTAssertEqual(AppVersion.display(marketing: "0.1.147", build: "147"), "0.1.147")
        XCTAssertEqual(AppVersion.display(marketing: "0.1.14", build: "4"), "0.1.14 (4)")
    }

    func testCopesWithAMissingVersion() {
        XCTAssertEqual(AppVersion.display(marketing: "", build: "47"), "build 47")
        XCTAssertEqual(AppVersion.display(marketing: "", build: ""), "")
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(AppVersion.display(marketing: " 1.0 ", build: " 9 "), "1.0 (9)")
    }
}
