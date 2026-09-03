import XCTest
@testable import PaneRailKit

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

    private func makeProvider() -> VivaldiRailProvider {
        VivaldiRailProvider(sender: sender, preferencesURL: fileURL)
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

    /// The active workspace is not discoverable, so nothing may claim to be it.
    func testNoRowIsMarkedActive() {
        write(names: ["Work", "Home"])
        XCTAssertTrue(makeProvider().items(for: vivaldi()).allSatisfy { !$0.isActive })
    }

    func testWorkspacesBeyondTheNinthAreShownDimmed() {
        write(names: (1...11).map { "W\($0)" })
        let items = makeProvider().items(for: vivaldi())
        XCTAssertEqual(items.count, 11)
        XCTAssertEqual(items.filter(\.isDimmed).map(\.id), [9, 10])
    }

    func testSelectingSendsTheMatchingShortcut() {
        write(names: ["Work", "Home", "Media"])
        let provider = makeProvider()
        let app = vivaldi(pid: 4321)

        XCTAssertTrue(provider.activate(RailItem(id: 2, title: "Media"), in: app))
        XCTAssertEqual(sender.sent.count, 1)
        XCTAssertEqual(sender.sent.first?.digit, 3, "index 2 is the third workspace")
        XCTAssertEqual(sender.sent.first?.pid, 4321)
    }

    /// Vivaldi has no shortcut past the ninth, so a click there must fail
    /// honestly instead of sending a keystroke that does something else.
    func testSelectingBeyondTheNinthSendsNothing() {
        write(names: (1...11).map { "W\($0)" })
        let provider = makeProvider()
        XCTAssertFalse(provider.activate(RailItem(id: 9, title: "W10"), in: vivaldi()))
        XCTAssertTrue(sender.sent.isEmpty)
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
