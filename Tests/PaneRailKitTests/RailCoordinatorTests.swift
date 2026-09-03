import Combine
import XCTest
@testable import PaneRailKit

final class RailCoordinatorTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        suiteName = "dev.kafeg.panerail.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        cancellables.removeAll()
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private let pid: pid_t = 501

    private func makeApp(bundleID: String? = "com.example.editor", name: String = "Editor") -> FrontmostApp {
        FrontmostApp(pid: pid, bundleIdentifier: bundleID, name: name)
    }

    private func makeSource(_ titles: [String]) -> FakeWindowSource {
        let windows = titles.enumerated().map { WindowInfo(id: UInt64($0.offset + 1), title: $0.element) }
        return FakeWindowSource(windowsByPID: [pid: windows])
    }

    private func makeCoordinator(
        source: WindowSource,
        isTrusted: @escaping () -> Bool = { true }
    ) -> (RailCoordinator, Preferences) {
        let preferences = Preferences(defaults: defaults)
        return (
            RailCoordinator(source: source, preferences: preferences, isTrusted: isTrusted),
            preferences
        )
    }

    func testLoadsWindowsForTheFrontmostApp() {
        let (coordinator, _) = makeCoordinator(source: makeSource(["one", "two", "three"]))
        coordinator.setFrontmost(makeApp())

        XCTAssertEqual(coordinator.items.map(\.title), ["one", "two", "three"])
        XCTAssertTrue(coordinator.isVisible)
    }

    func testUntitledWindowsAdoptTheAppName() {
        let (coordinator, _) = makeCoordinator(source: makeSource(["", "notes"]))
        coordinator.setFrontmost(makeApp(name: "Preview"))

        XCTAssertEqual(coordinator.items.map(\.title), ["Preview", "notes"])
    }

    func testNoFrontmostAppClearsEverything() {
        let (coordinator, _) = makeCoordinator(source: makeSource(["one", "two"]))
        coordinator.setFrontmost(makeApp())
        XCTAssertTrue(coordinator.isVisible)

        coordinator.setFrontmost(nil)
        XCTAssertTrue(coordinator.items.isEmpty)
        XCTAssertFalse(coordinator.isVisible)
    }

    func testHiddenBelowTheWindowThreshold() {
        let (coordinator, _) = makeCoordinator(source: makeSource(["only one"]))
        coordinator.setFrontmost(makeApp())

        XCTAssertEqual(coordinator.items.count, 1, "the list is still populated")
        XCTAssertFalse(coordinator.isVisible, "but the rail stays hidden")
    }

    func testWithoutAccessibilityThereAreNoWindows() {
        let (coordinator, _) = makeCoordinator(source: makeSource(["one", "two"]), isTrusted: { false })
        coordinator.setFrontmost(makeApp())

        XCTAssertTrue(coordinator.items.isEmpty)
        XCTAssertFalse(coordinator.isVisible)
    }

    func testSwitchingAppsSwapsTheWindowList() {
        let otherPID: pid_t = 777
        let source = FakeWindowSource(windowsByPID: [
            pid: [WindowInfo(id: 1, title: "a"), WindowInfo(id: 2, title: "b")],
            otherPID: [WindowInfo(id: 3, title: "c"), WindowInfo(id: 4, title: "d")],
        ])
        let (coordinator, _) = makeCoordinator(source: source)

        coordinator.setFrontmost(makeApp())
        XCTAssertEqual(coordinator.items.map(\.title), ["a", "b"])

        coordinator.setFrontmost(FrontmostApp(pid: otherPID, bundleIdentifier: "com.example.other", name: "Other"))
        XCTAssertEqual(coordinator.items.map(\.title), ["c", "d"])
    }

    func testSelectRaisesTheWindowUnderTheOwningProcess() {
        let source = makeSource(["one", "two"])
        let (coordinator, _) = makeCoordinator(source: source)
        coordinator.setFrontmost(makeApp())

        let target = coordinator.items[1]
        XCTAssertTrue(coordinator.select(target))
        XCTAssertEqual(source.raiseCalls.count, 1)
        XCTAssertEqual(source.raiseCalls.first?.window.id, target.id)
        XCTAssertEqual(source.raiseCalls.first?.pid, pid)
    }

    func testSelectIsANoOpWithoutAFrontmostApp() {
        let source = makeSource(["one"])
        let (coordinator, _) = makeCoordinator(source: source)

        XCTAssertFalse(coordinator.select(RailItem(id: 1, title: "one")))
        XCTAssertTrue(source.raiseCalls.isEmpty)
    }

    func testSelectReportsFailureFromTheSource() {
        let source = makeSource(["one", "two"])
        source.raiseResult = false
        let (coordinator, _) = makeCoordinator(source: source)
        coordinator.setFrontmost(makeApp())

        XCTAssertFalse(coordinator.select(coordinator.items[0]))
    }

    func testAllowListModeHidesUnlistedApps() {
        let (coordinator, preferences) = makeCoordinator(source: makeSource(["one", "two"]))
        preferences.mode = .listedApps
        coordinator.setFrontmost(makeApp())
        XCTAssertFalse(coordinator.isVisible)

        preferences.addListed("com.example.editor")
        coordinator.refresh()
        XCTAssertTrue(coordinator.isVisible)
    }

    /// Changing a setting has to take effect immediately rather than at the
    /// next poll, so the coordinator subscribes to the preferences store.
    func testPreferenceChangesTriggerARefresh() {
        let (coordinator, preferences) = makeCoordinator(source: makeSource(["one", "two"]))
        coordinator.setFrontmost(makeApp())
        XCTAssertTrue(coordinator.isVisible)

        let hidden = expectation(description: "rail hides after being disabled")
        coordinator.$isVisible
            .dropFirst()
            .filter { $0 == false }
            .sink { _ in hidden.fulfill() }
            .store(in: &cancellables)

        preferences.isEnabled = false
        wait(for: [hidden], timeout: 2)
    }

    /// While the rail is switched off the AX source must not be queried at all.
    func testDisabledRailDoesNotReadWindows() {
        let source = makeSource(["one", "two"])
        let (coordinator, preferences) = makeCoordinator(source: source)
        coordinator.setFrontmost(makeApp())
        XCTAssertFalse(coordinator.items.isEmpty)

        preferences.isEnabled = false
        coordinator.refresh()

        XCTAssertTrue(coordinator.items.isEmpty)
        XCTAssertFalse(coordinator.isVisible)
    }

    func testRefreshPicksUpNewWindows() {
        let source = makeSource(["one"])
        let (coordinator, _) = makeCoordinator(source: source)
        coordinator.setFrontmost(makeApp())
        XCTAssertFalse(coordinator.isVisible)

        source.windowsByPID[pid]?.append(WindowInfo(id: 99, title: "two"))
        coordinator.refresh()

        XCTAssertEqual(coordinator.items.count, 2)
        XCTAssertTrue(coordinator.isVisible)
    }
}
