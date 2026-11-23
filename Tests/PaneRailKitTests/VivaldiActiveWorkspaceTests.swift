import XCTest
@testable import PaneRailKit

final class VivaldiActiveWorkspaceTests: XCTestCase {
    private let workspaces = ["Work", "Home", "Reading", "Music", "Errands"]
        .enumerated()
        .map { VivaldiWorkspace(id: Double($0.offset), name: $0.element, index: $0.offset) }

    private func activeIndex(
        named: [Int: [String]],
        inUse: [String] = [],
        openTab: String
    ) -> Int? {
        VivaldiActiveWorkspace.activeIndex(
            among: workspaces,
            reading: VivaldiMenuReading(tabsByWorkspace: named, tabsOfWorkspaceInUse: inUse),
            openTab: openTab
        )
    }

    // MARK: - The rule

    /// The regression: Vivaldi rebuilds this menu when its own shortcut
    /// switches workspace, but not when the switch is made in its interface, so
    /// the menu goes on naming the workspace from before as the one in use.
    /// Which workspace holds which tab is still right, and that is what decides.
    func testTheWorkspaceHoldingTheOpenTabIsActiveEvenWhenTheMenuIsOutOfDate() {
        XCTAssertEqual(
            activeIndex(
                named: [0: ["Daily standup"], 1: ["Pension forms"], 3: ["Album"], 4: ["Shopping list"]],
                inUse: ["Daily standup", "Release notes"],
                openTab: "Pension forms - Vivaldi"
            ),
            1
        )
    }

    func testTheWorkspaceInUseIsActiveWhenItHoldsTheOpenTab() {
        XCTAssertEqual(
            activeIndex(
                named: [0: ["Daily standup"], 1: ["Pension forms"], 3: ["Album"], 4: ["Shopping list"]],
                inUse: ["Release notes", "Timetable"],
                openTab: "Release notes - Vivaldi"
            ),
            2
        )
    }

    func testAPageOpenInTwoWorkspacesHighlightsNothing() {
        XCTAssertNil(
            activeIndex(
                named: [0: ["Shared page"], 1: ["Pension forms"], 3: ["Shared page"], 4: ["Shopping list"]],
                openTab: "Shared page - Vivaldi"
            )
        )
    }

    func testATabNoWorkspaceListsHighlightsNothing() {
        XCTAssertNil(
            activeIndex(
                named: [0: ["Daily standup"], 1: ["Pension forms"], 3: ["Album"], 4: ["Shopping list"]],
                inUse: ["Release notes"],
                openTab: "A page opened a moment ago - Vivaldi"
            )
        )
    }

    /// Two workspaces are missing from the menu, so its own tab list belongs to
    /// one of them and there is no telling which.
    func testTwoWorkspacesOutsideTheMenuHighlightNothing() {
        XCTAssertNil(
            activeIndex(
                named: [0: ["Daily standup"], 1: ["Pension forms"], 3: ["Album"]],
                inUse: ["Release notes"],
                openTab: "Release notes - Vivaldi"
            )
        )
    }

    func testTooFewWorkspacesNamedToBeTheWorkspaceMenu() {
        XCTAssertNil(activeIndex(named: [0: ["Daily standup"]], openTab: "Daily standup - Vivaldi"))
    }

    func testASingleWorkspaceHasNothingToHighlight() {
        let one = [VivaldiWorkspace(id: 0, name: "Work", index: 0)]
        XCTAssertNil(VivaldiActiveWorkspace.activeIndex(
            among: one,
            reading: VivaldiMenuReading(tabsByWorkspace: [:], tabsOfWorkspaceInUse: ["Daily standup"]),
            openTab: "Daily standup - Vivaldi"
        ))
    }

    // MARK: - Recognising the open tab among shortened entries

    func testTheOpenTabIsFoundAmongTheMenuEntries() {
        XCTAssertTrue(VivaldiActiveWorkspace.menu(
            ["Minimize", "Quarterly planning notes"],
            shows: "Quarterly planning notes - Vivaldi"
        ))
    }

    /// Long entries are cut in the middle, which is where the old comparison
    /// gave up: joining the two halves is not the beginning of the title.
    func testAnEntryCutInTheMiddleMatchesTheTitleItWasCutFrom() {
        XCTAssertTrue(VivaldiActiveWorkspace.menu(
            ["Quarterly planning\u{2026}and the budget"],
            shows: "Quarterly planning notes for next year and the budget - Vivaldi"
        ))
    }

    func testAnEntryCutAtTheEndMatchesTheTitleItWasCutFrom() {
        XCTAssertTrue(VivaldiActiveWorkspace.menu(
            ["Quarterly planning no\u{2026}"],
            shows: "Quarterly planning notes and budget - Vivaldi"
        ))
    }

    func testAnEntryCutInTheMiddleOfAnotherTitleDoesNotMatch() {
        XCTAssertFalse(VivaldiActiveWorkspace.menu(
            ["Quarterly planning\u{2026}and the budget"],
            shows: "Quarterly planning notes for next year and the appendix - Vivaldi"
        ))
    }

    /// Vivaldi puts a bullet in front of the tab a list is showing.
    func testAMarkedEntryMatchesTheTitleWithoutTheMark() {
        XCTAssertTrue(VivaldiActiveWorkspace.menu(
            ["\u{2022} Quarterly planning notes"],
            shows: "Quarterly planning notes - Vivaldi"
        ))
    }

    func testAnUnrelatedMenuDoesNotCountAsTheWindow() {
        XCTAssertFalse(VivaldiActiveWorkspace.menu(
            ["Minimize", "Zoom", "Bring All to Front"],
            shows: "Quarterly planning notes - Vivaldi"
        ))
    }

    func testAnEmptyWindowTitleMatchesNothing() {
        XCTAssertFalse(VivaldiActiveWorkspace.menu(["Minimize", ""], shows: ""))
    }

    /// A couple of letters in common would match half the web, so short titles
    /// have to agree in full.
    func testShortTitlesHaveToMatchWhole() {
        XCTAssertFalse(VivaldiActiveWorkspace.menu(["Inbox"], shows: "Inbox (12) - Vivaldi"))
        XCTAssertTrue(VivaldiActiveWorkspace.menu(["Inbox (12)"], shows: "Inbox (12) - Vivaldi"))
    }

    // MARK: - Window titles

    func testOnlyVivaldisOwnSuffixIsDropped() {
        XCTAssertEqual(
            VivaldiActiveWorkspace.tabTitle(fromWindowTitle: "Swift - AppKit - docs - Vivaldi"),
            "Swift - AppKit - docs"
        )
    }

    func testATitleWithoutTheSuffixIsKeptWhole() {
        XCTAssertEqual(
            VivaldiActiveWorkspace.tabTitle(fromWindowTitle: "Swift - AppKit"),
            "Swift - AppKit"
        )
    }
}
