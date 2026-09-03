import XCTest
@testable import PaneRailKit

/// Stands in for an app that keeps its own internal states.
private final class StubProvider: RailItemProvider {
    let claims: String
    let rows: [RailItem]
    private(set) var activated: [RailItem] = []

    init(claims bundleID: String, rows: [RailItem]) {
        self.claims = bundleID
        self.rows = rows
    }

    func supports(_ app: FrontmostApp) -> Bool { app.bundleIdentifier == claims }
    func items(for app: FrontmostApp) -> [RailItem] { rows }

    func activate(_ item: RailItem, in app: FrontmostApp) -> Bool {
        activated.append(item)
        return true
    }
}

final class RailProviderSelectionTests: XCTestCase {
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

    private let pid: pid_t = 77

    /// App-specific providers are opt-in, so tests that exercise one have to
    /// switch it on the way a user would.
    private func makeCoordinator(
        windows: [String],
        special: StubProvider?,
        appSpecificProviders: Bool = true
    ) -> (RailCoordinator, Preferences) {
        let source = FakeWindowSource(windowsByPID: [
            pid: windows.enumerated().map { WindowInfo(id: UInt64($0.offset + 1), title: $0.element) },
        ])
        let preferences = Preferences(defaults: defaults)
        preferences.appSpecificProviders = appSpecificProviders
        let coordinator = RailCoordinator(
            windowProvider: WindowRailProvider(source: source),
            appSpecificProviders: special.map { [$0] } ?? [],
            preferences: preferences
        )
        return (coordinator, preferences)
    }

    private func app(_ bundleID: String) -> FrontmostApp {
        FrontmostApp(pid: pid, bundleIdentifier: bundleID, name: "App")
    }

    func testAppSpecificProviderWinsForTheAppItClaims() {
        let special = StubProvider(claims: "com.example.browser", rows: [
            RailItem(id: 10, title: "Work"),
            RailItem(id: 11, title: "Home"),
        ])
        let (coordinator, _) = makeCoordinator(windows: ["window a", "window b"], special: special)

        coordinator.setFrontmost(app("com.example.browser"))
        XCTAssertEqual(coordinator.items.map(\.title), ["Work", "Home"])
    }

    func testOtherAppsStillGetTheirWindows() {
        let special = StubProvider(claims: "com.example.browser", rows: [RailItem(id: 10, title: "Work")])
        let (coordinator, _) = makeCoordinator(windows: ["window a", "window b"], special: special)

        coordinator.setFrontmost(app("com.example.editor"))
        XCTAssertEqual(coordinator.items.map(\.title), ["window a", "window b"])
    }

    func testTheSettingTurnsAppSpecificProvidersOff() {
        let special = StubProvider(claims: "com.example.browser", rows: [RailItem(id: 10, title: "Work")])
        let (coordinator, preferences) = makeCoordinator(windows: ["window a", "window b"], special: special)
        preferences.appSpecificProviders = false

        coordinator.setFrontmost(app("com.example.browser"))
        XCTAssertEqual(coordinator.items.map(\.title), ["window a", "window b"])
    }

    /// The feature rests on undocumented internals of other apps, so a user who
    /// has never touched the setting must get plain window switching.
    func testAppSpecificProvidersAreIgnoredUntilSwitchedOn() {
        let special = StubProvider(claims: "com.example.browser", rows: [RailItem(id: 10, title: "Work")])
        let (coordinator, preferences) = makeCoordinator(
            windows: ["window a", "window b"], special: special, appSpecificProviders: false
        )
        XCTAssertFalse(preferences.appSpecificProviders, "the default, not something the test set")

        coordinator.setFrontmost(app("com.example.browser"))
        XCTAssertEqual(coordinator.items.map(\.title), ["window a", "window b"])
    }

    /// A click has to reach whichever provider produced the row.
    func testSelectionGoesToTheProviderThatSuppliedTheRow() {
        let special = StubProvider(claims: "com.example.browser", rows: [RailItem(id: 10, title: "Work")])
        let (coordinator, _) = makeCoordinator(windows: ["window a"], special: special)

        coordinator.setFrontmost(app("com.example.browser"))
        XCTAssertTrue(coordinator.select(coordinator.items[0]))
        XCTAssertEqual(special.activated.map(\.id), [10])
    }

    func testSwitchingAppsSwitchesProviders() {
        let special = StubProvider(claims: "com.example.browser", rows: [RailItem(id: 10, title: "Work")])
        let (coordinator, _) = makeCoordinator(windows: ["window a", "window b"], special: special)

        coordinator.setFrontmost(app("com.example.browser"))
        XCTAssertEqual(coordinator.items.map(\.title), ["Work"])

        coordinator.setFrontmost(app("com.example.editor"))
        XCTAssertEqual(coordinator.items.map(\.title), ["window a", "window b"])
    }
}
