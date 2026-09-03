import XCTest
@testable import PaneRailKit

private final class FakeActiveReader: VivaldiActiveWorkspaceReading {
    var index: Int?

    init(index: Int? = nil) { self.index = index }

    func activeIndex(among workspaces: [VivaldiWorkspace], pid: pid_t) -> Int? { index }
}

private final class FakeShortcutSender: ShortcutSending {
    private(set) var sent: [(digit: Int, pid: pid_t)] = []

    func sendControlShift(digit: Int, to pid: pid_t) {
        sent.append((digit, pid))
    }
}

final class VivaldiRailProviderTests: XCTestCase {
    private var fileURL: URL!
    private var sender: FakeShortcutSender!

    override func setUp() {
        super.setUp()
        sender = FakeShortcutSender()
        fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("panerail-vivaldi-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    private func write(names: [String]) {
        let entries = names.enumerated()
            .map { #"{"id":\#($0.offset + 1),"name":"\#($0.element)"}"# }
            .joined(separator: ",")
        try? Data(#"{"vivaldi":{"workspaces":{"list":[\#(entries)]}}}"#.utf8).write(to: fileURL)
    }

    private func makeProvider(active: Int? = nil) -> VivaldiRailProvider {
        VivaldiRailProvider(
            sender: sender,
            activeReader: FakeActiveReader(index: active),
            preferencesURL: fileURL
        )
    }

    private func vivaldi(pid: pid_t = 900) -> FrontmostApp {
        FrontmostApp(pid: pid, bundleIdentifier: VivaldiWorkspaces.bundleIdentifier, name: "Vivaldi")
    }

    func testClaimsVivaldiWhenWorkspacesCanBeRead() {
        write(names: ["Work", "Home"])
        XCTAssertTrue(makeProvider().supports(vivaldi()))
    }

    func testIgnoresOtherApplications() {
        write(names: ["Work"])
        let other = FrontmostApp(pid: 1, bundleIdentifier: "com.apple.Safari", name: "Safari")
        XCTAssertFalse(makeProvider().supports(other))
    }

    /// An unreadable profile must hand the app back to plain window switching
    /// rather than leave the rail empty.
    func testDoesNotClaimVivaldiWhenTheProfileCannotBeRead() {
        XCTAssertFalse(makeProvider().supports(vivaldi()), "no file at all")

        try? Data(#"{"vivaldi":{"workspaces":{}}}"#.utf8).write(to: fileURL)
        XCTAssertFalse(makeProvider().supports(vivaldi()), "layout it does not understand")
    }

    func testItemsFollowTheStoredOrder() {
        write(names: ["Work", "Home", "Media"])
        let items = makeProvider().items(for: vivaldi())
        XCTAssertEqual(items.map(\.title), ["Work", "Home", "Media"])
        XCTAssertEqual(items.map(\.id), [0, 1, 2])
    }

    func testTheActiveWorkspaceIsMarked() {
        write(names: ["Work", "Home", "Media"])
        let items = makeProvider(active: 1).items(for: vivaldi())
        XCTAssertEqual(items.filter(\.isActive).map(\.title), ["Home"])
    }

    /// When the active workspace cannot be established, highlighting the wrong
    /// row would be worse than highlighting none.
    func testNothingIsMarkedWhenTheActiveWorkspaceIsUnknown() {
        write(names: ["Work", "Home"])
        XCTAssertTrue(makeProvider(active: nil).items(for: vivaldi()).allSatisfy { !$0.isActive })
    }

    /// Ctrl+Shift+1 selects the window's own tabs rather than a workspace, so
    /// the first workspace answers to the second digit and only eight fit.
    func testWorkspacesPastTheLastShortcutAreShownDimmed() {
        write(names: (1...11).map { "W\($0)" })
        let items = makeProvider().items(for: vivaldi())
        XCTAssertEqual(items.count, 11)
        XCTAssertEqual(items.filter(\.isDimmed).map(\.id), [8, 9, 10])
        XCTAssertEqual(VivaldiRailProvider.switchableCount, 8)
    }

    func testShortcutDigitsSkipTheNoWorkspaceEntry() {
        XCTAssertEqual(VivaldiRailProvider.shortcutDigit(forWorkspaceAt: 0), 2)
        XCTAssertEqual(VivaldiRailProvider.shortcutDigit(forWorkspaceAt: 7), 9)
        XCTAssertNil(VivaldiRailProvider.shortcutDigit(forWorkspaceAt: 8))
    }

    func testSelectingSendsTheMatchingShortcut() {
        write(names: ["Work", "Home", "Media"])
        let provider = makeProvider()
        let app = vivaldi(pid: 4321)

        XCTAssertTrue(provider.activate(RailItem(id: 2, title: "Media"), in: app))
        XCTAssertEqual(sender.sent.count, 1)
        XCTAssertEqual(sender.sent.first?.digit, 4, "the third workspace is Ctrl+Shift+4")
        XCTAssertEqual(sender.sent.first?.pid, 4321)
    }

    /// Past the last bound shortcut a click must fail honestly rather than
    /// send a keystroke that does something else entirely.
    func testSelectingPastTheLastShortcutSendsNothing() {
        write(names: (1...11).map { "W\($0)" })
        let provider = makeProvider()
        XCTAssertFalse(provider.activate(RailItem(id: 8, title: "W9"), in: vivaldi()))
        XCTAssertTrue(sender.sent.isEmpty)
    }

    func testTheFirstWorkspaceUsesTheSecondDigit() {
        write(names: ["Work", "Home"])
        XCTAssertTrue(makeProvider().activate(RailItem(id: 0, title: "Work"), in: vivaldi()))
        XCTAssertEqual(sender.sent.first?.digit, 2)
    }

    func testPicksUpAnEditedProfile() {
        write(names: ["Work"])
        let provider = makeProvider()
        XCTAssertEqual(provider.items(for: vivaldi()).map(\.title), ["Work"])

        // A later modification date is what invalidates the cache.
        write(names: ["Work", "Home"])
        try? FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: fileURL.path
        )
        XCTAssertEqual(provider.items(for: vivaldi()).map(\.title), ["Work", "Home"])
    }
}
