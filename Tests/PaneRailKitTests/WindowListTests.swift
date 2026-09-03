import XCTest
@testable import PaneRailKit

final class WindowListTests: XCTestCase {
    func testEmptyTitlesFallBackToTheAppName() {
        let windows = [
            WindowInfo(id: 1, title: ""),
            WindowInfo(id: 2, title: "   "),
            WindowInfo(id: 3, title: "Notes.md"),
        ]
        let result = WindowList.normalize(windows, appName: "Code")
        XCTAssertEqual(result.map(\.title), ["Code", "Code", "Notes.md"])
    }

    func testTitlesAreTrimmed() {
        let result = WindowList.normalize([WindowInfo(id: 1, title: "  spaced  ")], appName: "Code")
        XCTAssertEqual(result.first?.title, "spaced")
    }

    func testFallsBackToAPlaceholderWhenTheAppHasNoNameEither() {
        let result = WindowList.normalize([WindowInfo(id: 1, title: "")], appName: "")
        XCTAssertEqual(result.first?.title, WindowTitle.untitled)
    }

    func testDuplicateWindowsAreDroppedKeepingTheFirst() {
        let windows = [
            WindowInfo(id: 7, title: "front"),
            WindowInfo(id: 8, title: "second"),
            WindowInfo(id: 7, title: "stale duplicate"),
        ]
        let result = WindowList.normalize(windows, appName: "Code")
        XCTAssertEqual(result.map(\.id), [7, 8])
        XCTAssertEqual(result.first?.title, "front")
    }

    func testOrderIsPreserved() {
        let windows = (1...5).map { WindowInfo(id: UInt64($0), title: "w\($0)") }
        XCTAssertEqual(WindowList.normalize(windows, appName: "Code").map(\.id), [1, 2, 3, 4, 5])
    }

    func testMinimizedWindowsAreKeptByDefault() {
        let windows = [
            WindowInfo(id: 1, title: "visible"),
            WindowInfo(id: 2, title: "hidden", isMinimized: true),
        ]
        XCTAssertEqual(WindowList.normalize(windows, appName: "Code").count, 2)
    }

    func testMinimizedWindowsCanBeExcluded() {
        let windows = [
            WindowInfo(id: 1, title: "visible"),
            WindowInfo(id: 2, title: "hidden", isMinimized: true),
        ]
        let result = WindowList.normalize(windows, appName: "Code", includeMinimized: false)
        XCTAssertEqual(result.map(\.id), [1])
    }

    func testFlagsAndHandlesAreCarriedThrough() {
        let windows = [WindowInfo(id: 1, title: "w", isMinimized: true, isFocused: true)]
        let result = WindowList.normalize(windows, appName: "Code")
        XCTAssertTrue(result[0].isMinimized)
        XCTAssertTrue(result[0].isFocused)
    }

    // MARK: - Title shortening

    func testShortenedLeavesShortTitlesAlone() {
        XCTAssertEqual(WindowTitle.shortened("README.md", limit: 20), "README.md")
    }

    func testShortenedTruncatesWithAnEllipsis() {
        let result = WindowTitle.shortened("a very long window title indeed", limit: 10)
        XCTAssertEqual(result.count, 10)
        XCTAssertTrue(result.hasSuffix("\u{2026}"))
    }

    func testShortenedHandlesDegenerateLimits() {
        XCTAssertEqual(WindowTitle.shortened("title", limit: 0), "")
        XCTAssertEqual(WindowTitle.shortened("title", limit: -1), "")
    }

    /// Equality drives SwiftUI's diffing; a re-read of the same window must not
    /// register as a change just because the AX element is a new object.
    func testEqualityIgnoresHandles() {
        let a = WindowInfo(id: 1, title: "w")
        let b = WindowInfo(id: 1, title: "w")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, WindowInfo(id: 1, title: "w", isFocused: true))
        XCTAssertNotEqual(a, WindowInfo(id: 2, title: "w"))
    }
}
