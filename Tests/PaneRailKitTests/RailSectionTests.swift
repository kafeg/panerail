import XCTest
@testable import PaneRailKit

/// Stands in for an app that keeps its own internal states.
private final class StubProvider: RailItemProvider {
    let claims: String
    let sectionID: String
    let rows: [RailItem]
    let layout: RailLayout
    private(set) var activated: [RailItem] = []
    private(set) var sectionRequests = 0

    init(claims bundleID: String, sectionID: String = "stub", rows: [RailItem], layout: RailLayout = .list) {
        self.claims = bundleID
        self.sectionID = sectionID
        self.rows = rows
        self.layout = layout
    }

    func supports(_ app: FrontmostApp) -> Bool { app.bundleIdentifier == claims }

    func section(for app: FrontmostApp) -> RailSection? {
        sectionRequests += 1
        return RailSection(id: sectionID, title: "Stub", layout: layout, items: rows)
    }

    func activate(_ item: RailItem, in app: FrontmostApp) -> Bool {
        activated.append(item)
        return true
    }
}

final class RailSectionTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private let pid: pid_t = 77

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

    private func stub(rows: Int = 2, layout: RailLayout = .list) -> StubProvider {
        StubProvider(
            claims: "com.example.browser",
            rows: (0..<rows).map { RailItem(id: UInt64($0), title: "state \($0)") },
            layout: layout
        )
    }

    // MARK: - Composition

    /// The whole point: an app with internal states keeps its windows too. It
    /// is precisely when a browser has a private window open beside a normal
    /// one that switching between windows matters.
    func testAnAppSpecificProviderAddsToTheWindowsRatherThanReplacingThem() {
        let (coordinator, _) = makeCoordinator(windows: ["one", "two"], special: stub())
        coordinator.setFrontmost(app("com.example.browser"))

        XCTAssertEqual(coordinator.sections.map(\.id), [WindowRailProvider.sectionID, "stub"])
        XCTAssertEqual(coordinator.sections.first?.items.map(\.title), ["one", "two"])
        XCTAssertEqual(coordinator.sections.last?.items.map(\.title), ["state 0", "state 1"])
    }

    func testWindowsComeFirst() {
        let (coordinator, _) = makeCoordinator(windows: ["one", "two"], special: stub())
        coordinator.setFrontmost(app("com.example.browser"))
        XCTAssertEqual(coordinator.sections.first?.id, WindowRailProvider.sectionID)
    }

    func testOtherAppsGetOnlyTheirWindows() {
        let special = stub()
        let (coordinator, _) = makeCoordinator(windows: ["one", "two"], special: special)
        coordinator.setFrontmost(app("com.example.editor"))

        XCTAssertEqual(coordinator.sections.map(\.id), [WindowRailProvider.sectionID])
        XCTAssertEqual(special.sectionRequests, 0, "a provider that does not claim the app is not asked")
    }

    func testTheSettingTurnsAppSpecificSectionsOff() {
        let (coordinator, _) = makeCoordinator(windows: ["one", "two"], special: stub(), appSpecificProviders: false)
        coordinator.setFrontmost(app("com.example.browser"))
        XCTAssertEqual(coordinator.sections.map(\.id), [WindowRailProvider.sectionID])
    }

    // MARK: - The window threshold

    /// "Appear from n windows" is about windows. One window beside eight
    /// workspaces is a row of noise, but the workspaces are still worth showing.
    func testASingleWindowDropsTheWindowSectionButKeepsTheOther() {
        let (coordinator, _) = makeCoordinator(windows: ["only one"], special: stub())
        coordinator.setFrontmost(app("com.example.browser"))

        XCTAssertEqual(coordinator.sections.map(\.id), ["stub"])
        XCTAssertTrue(coordinator.isVisible)
    }

    func testASingleWindowAndNothingElseHidesTheRail() {
        let (coordinator, _) = makeCoordinator(windows: ["only one"], special: nil)
        coordinator.setFrontmost(app("com.example.editor"))

        XCTAssertTrue(coordinator.sections.isEmpty)
        XCTAssertFalse(coordinator.isVisible)
    }

    func testAnEmptySectionIsLeftOut() {
        let (coordinator, _) = makeCoordinator(windows: ["one", "two"], special: stub(rows: 0))
        coordinator.setFrontmost(app("com.example.browser"))
        XCTAssertEqual(coordinator.sections.map(\.id), [WindowRailProvider.sectionID])
    }

    // MARK: - Identity and routing

    /// Window ids are accessibility hashes and workspace ids are positions, so
    /// the two spaces overlap freely. Scoping by section is what stops a click
    /// landing in the wrong place.
    func testRowsFromDifferentSectionsNeverShareAnIdentity() {
        // Deliberately the same local numbering on both sides.
        let special = StubProvider(
            claims: "com.example.browser",
            rows: [RailItem(id: 1, title: "state"), RailItem(id: 2, title: "other state")]
        )
        let (coordinator, _) = makeCoordinator(windows: ["one", "two"], special: special)
        coordinator.setFrontmost(app("com.example.browser"))

        let ids = coordinator.sections.flatMap { $0.items.map(\.id) }
        XCTAssertEqual(Set(ids).count, ids.count, "identities collided across sections")
        XCTAssertEqual(ids.map(\.value).sorted(), [1, 1, 2, 2], "and the local numbering really did overlap")
    }

    func testAClickGoesToTheProviderThatOwnsTheRow() {
        let special = stub()
        let (coordinator, _) = makeCoordinator(windows: ["one", "two"], special: special)
        coordinator.setFrontmost(app("com.example.browser"))

        let stateRow = coordinator.sections.last!.items[0]
        XCTAssertTrue(coordinator.select(stateRow))
        XCTAssertEqual(special.activated.map(\.title), ["state 0"])
    }

    func testAClickOnAWindowDoesNotReachTheOtherProvider() {
        let special = stub()
        let (coordinator, _) = makeCoordinator(windows: ["one", "two"], special: special)
        coordinator.setFrontmost(app("com.example.browser"))

        XCTAssertTrue(coordinator.select(coordinator.sections.first!.items[0]))
        XCTAssertTrue(special.activated.isEmpty)
    }

    func testAnUnknownSectionIsRefused() {
        let (coordinator, _) = makeCoordinator(windows: ["one", "two"], special: nil)
        coordinator.setFrontmost(app("com.example.editor"))
        XCTAssertFalse(coordinator.select(RailItem(id: 1, title: "from nowhere")))
    }

    // MARK: - Layout

    /// Each section is a panel of its own, so a section carries the shape its
    /// own panel takes.
    func testASectionCarriesTheShapeOfItsPanel() {
        let (coordinator, _) = makeCoordinator(windows: ["one", "two"], special: stub(layout: .glyphs))
        coordinator.setFrontmost(app("com.example.browser"))

        XCTAssertEqual(coordinator.sections.first?.layout, .list)
        XCTAssertEqual(coordinator.sections.last?.layout, .glyphs)
    }
}
