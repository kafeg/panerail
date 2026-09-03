import AppKit
import XCTest
@testable import PaneRailKit

final class AppDescriptorTests: XCTestCase {
    func testDedupedSortedIsCaseInsensitiveAndStable() {
        let apps = [
            AppDescriptor(bundleIdentifier: "com.b", name: "zebra"),
            AppDescriptor(bundleIdentifier: "com.a", name: "Alpha"),
            AppDescriptor(bundleIdentifier: "com.c", name: "middle"),
        ]
        XCTAssertEqual(RunningApps.dedupedSorted(apps).map(\.name), ["Alpha", "middle", "zebra"])
    }

    func testDedupedSortedDropsRepeatedBundleIdentifiers() {
        let apps = [
            AppDescriptor(bundleIdentifier: "com.a", name: "Alpha"),
            AppDescriptor(bundleIdentifier: "com.a", name: "Alpha (duplicate)"),
        ]
        let result = RunningApps.dedupedSorted(apps)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Alpha", "the first occurrence wins")
    }

    func testEqualityIgnoresIcons() {
        let a = AppDescriptor(bundleIdentifier: "com.a", name: "Alpha", icon: nil)
        let b = AppDescriptor(bundleIdentifier: "com.a", name: "Alpha", icon: NSImage())
        XCTAssertEqual(a, b)
    }
}
