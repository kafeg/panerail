import XCTest
@testable import PaneRailKit

final class VivaldiWorkspacesTests: XCTestCase {
    private func preferences(_ json: String) -> Data { Data(json.utf8) }

    func testParsesTheWorkspaceList() throws {
        let data = preferences("""
        {"vivaldi":{"workspaces":{"list":[
          {"id":1712000000001,"name":"Alpha","icon":"a","iconId":"1"},
          {"id":1712000000002,"name":"Beta","icon":"b","iconId":"2"}
        ]}}}
        """)
        let result = try VivaldiWorkspaces.parse(preferences: data)
        XCTAssertEqual(result.map(\.name), ["Alpha", "Beta"])
        XCTAssertEqual(result.map(\.index), [0, 1])
        XCTAssertEqual(result[0].id, 1712000000001)
    }

    /// The index is what the built-in Ctrl+Shift+<n> shortcut counts, so it has
    /// to follow the stored order even when entries are skipped.
    func testIndexFollowsStoredOrderAcrossSkippedEntries() throws {
        let data = preferences("""
        {"vivaldi":{"workspaces":{"list":[
          {"id":1,"name":"Alpha"},
          {"id":2,"name":"   "},
          {"id":3,"name":"Gamma"}
        ]}}}
        """)
        let result = try VivaldiWorkspaces.parse(preferences: data)
        XCTAssertEqual(result.map(\.name), ["Alpha", "Gamma"])
        XCTAssertEqual(result.map(\.index), [0, 2], "the blank entry still occupies its slot")
    }

    func testTrimsNames() throws {
        let data = preferences(#"{"vivaldi":{"workspaces":{"list":[{"id":1,"name":"  Alpha  "}]}}}"#)
        XCTAssertEqual(try VivaldiWorkspaces.parse(preferences: data).first?.name, "Alpha")
    }

    func testEmptyListIsNotAnError() throws {
        let data = preferences(#"{"vivaldi":{"workspaces":{"list":[]}}}"#)
        XCTAssertTrue(try VivaldiWorkspaces.parse(preferences: data).isEmpty)
    }

    /// This is undocumented internal structure; a Vivaldi update that moves it
    /// must degrade to plain window switching, not crash.
    func testMissingKeysReportAnUnexpectedLayout() {
        for json in [
            #"{}"#,
            #"{"vivaldi":{}}"#,
            #"{"vivaldi":{"workspaces":{}}}"#,
            #"{"vivaldi":{"workspaces":{"list":"not an array"}}}"#,
        ] {
            XCTAssertThrowsError(try VivaldiWorkspaces.parse(preferences: preferences(json))) { error in
                XCTAssertEqual(error as? VivaldiWorkspacesError, .unexpectedLayout, json)
            }
        }
    }

    func testMalformedJSONIsReportedAsUnreadable() {
        XCTAssertThrowsError(try VivaldiWorkspaces.parse(preferences: preferences("{not json"))) { error in
            XCTAssertEqual(error as? VivaldiWorkspacesError, .unreadable)
        }
    }

    func testLoadingAMissingFileYieldsNothing() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("panerail-absent-\(UUID().uuidString)")
        XCTAssertTrue(VivaldiWorkspaces.load(from: url).isEmpty)
    }
}

final class VivaldiWorkspacesStatusTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("panerail-status-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    private func write(_ json: String) {
        try? Data(json.utf8).write(to: fileURL)
    }

    func testReportsHowManyWorkspacesWereFound() {
        write(#"{"vivaldi":{"workspaces":{"list":[{"id":1,"name":"Work"},{"id":2,"name":"Home"}]}}}"#)
        XCTAssertEqual(VivaldiWorkspaces.status(at: fileURL), .ok(count: 2))
    }

    func testReportsAMissingProfile() {
        XCTAssertEqual(VivaldiWorkspaces.status(at: fileURL), .profileNotFound)
    }

    func testReportsAnUnreadableFile() {
        write("{not json")
        XCTAssertEqual(VivaldiWorkspaces.status(at: fileURL), .unreadable)
    }

    /// The case worth telling the user about by name: a Vivaldi update moved
    /// the list, and no amount of retrying will help.
    func testReportsAnUnfamiliarLayout() {
        write(#"{"vivaldi":{"workspaces":{}}}"#)
        XCTAssertEqual(VivaldiWorkspaces.status(at: fileURL), .unexpectedLayout)
    }

    func testDistinguishesNoWorkspacesFromAFailure() {
        write(#"{"vivaldi":{"workspaces":{"list":[]}}}"#)
        XCTAssertEqual(VivaldiWorkspaces.status(at: fileURL), .noWorkspaces)
    }
}
