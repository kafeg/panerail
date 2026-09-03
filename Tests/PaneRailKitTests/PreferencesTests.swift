import Combine
import XCTest
@testable import PaneRailKit

final class PreferencesTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "dev.kafeg.panerail.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makePreferences() -> Preferences {
        Preferences(defaults: defaults)
    }

    func testDefaults() {
        let preferences = makePreferences()
        XCTAssertTrue(preferences.isEnabled)
        XCTAssertEqual(preferences.mode, .allApps)
        XCTAssertEqual(preferences.minimumWindows, 2)
        XCTAssertEqual(preferences.width, Preferences.defaultWidth)
        XCTAssertTrue(preferences.listedBundleIDs.isEmpty)
        XCTAssertNil(preferences.savedOrigin)
    }

    func testValuesSurviveARestart() {
        let first = makePreferences()
        first.isEnabled = false
        first.mode = .listedApps
        first.minimumWindows = 4
        first.width = 300
        first.addListed("com.example.editor")
        first.savedOrigin = CGPoint(x: 120, y: 640)

        let second = makePreferences()
        XCTAssertFalse(second.isEnabled)
        XCTAssertEqual(second.mode, .listedApps)
        XCTAssertEqual(second.minimumWindows, 4)
        XCTAssertEqual(second.width, 300)
        XCTAssertEqual(second.listedBundleIDs, ["com.example.editor"])
        XCTAssertEqual(second.savedOrigin, CGPoint(x: 120, y: 640))
    }

    func testWidthIsClampedOnAssignment() {
        let preferences = makePreferences()
        preferences.width = 10_000
        XCTAssertEqual(preferences.width, Preferences.maximumWidth)
        preferences.width = 1
        XCTAssertEqual(preferences.width, Preferences.minimumWidth)
    }

    /// A width written by a future version — or a corrupted domain — must not
    /// produce an unusable sliver of a panel.
    func testOutOfRangeStoredWidthIsClampedOnLoad() {
        defaults.set(5_000.0, forKey: Preferences.Key.width)
        XCTAssertEqual(makePreferences().width, Preferences.maximumWidth)
    }

    func testMinimumWindowsNeverDropsBelowOne() {
        let preferences = makePreferences()
        preferences.minimumWindows = 0
        XCTAssertEqual(preferences.minimumWindows, 1)
        preferences.minimumWindows = -3
        XCTAssertEqual(preferences.minimumWindows, 1)
    }

    func testStoredMinimumWindowsIsClampedOnLoad() {
        defaults.set(0, forKey: Preferences.Key.minimumWindows)
        XCTAssertEqual(makePreferences().minimumWindows, 1)
    }

    func testUnknownStoredModeFallsBackToAllApps() {
        defaults.set("someFutureMode", forKey: Preferences.Key.mode)
        XCTAssertEqual(makePreferences().mode, .allApps)
    }

    func testAllowListOperations() {
        let preferences = makePreferences()

        preferences.addListed("com.example.a")
        preferences.addListed("com.example.a")
        XCTAssertEqual(preferences.listedBundleIDs, ["com.example.a"], "duplicates must be ignored")

        preferences.addListed("")
        XCTAssertEqual(preferences.listedBundleIDs, ["com.example.a"], "empty ids must be ignored")

        preferences.toggleListed("com.example.b")
        XCTAssertTrue(preferences.isListed("com.example.b"))

        preferences.toggleListed("com.example.b")
        XCTAssertFalse(preferences.isListed("com.example.b"))

        preferences.removeListed("com.example.a")
        XCTAssertTrue(preferences.listedBundleIDs.isEmpty)
    }

    func testResetPositionClearsSavedOrigin() {
        let preferences = makePreferences()
        preferences.savedOrigin = CGPoint(x: 10, y: 20)
        preferences.resetPosition()
        XCTAssertNil(preferences.savedOrigin)
        XCTAssertNil(makePreferences().savedOrigin, "the reset must be persisted too")
    }

    /// The panel only repositions when it is told to. `savedOrigin` is computed
    /// and so publishes nothing on its own — without an explicit signal,
    /// "Reset to right edge" cleared the stored value and moved nothing.
    func testClearingThePositionNotifiesObservers() {
        let preferences = makePreferences()
        preferences.savedOrigin = CGPoint(x: 300, y: 700)

        var received = 0
        var cancellables = Set<AnyCancellable>()
        preferences.positionPublisher
            .dropFirst()
            .sink { _ in received += 1 }
            .store(in: &cancellables)

        preferences.resetPosition()
        XCTAssertEqual(received, 1)

        preferences.savedOrigin = CGPoint(x: 10, y: 20)
        XCTAssertEqual(received, 2, "storing a position must notify too")
    }

    /// A half-written position (one axis only) is meaningless and must not be
    /// read back as a partial origin.
    func testPartiallyStoredOriginIsIgnored() {
        defaults.set(100.0, forKey: Preferences.Key.originX)
        XCTAssertNil(makePreferences().savedOrigin)
    }
}
