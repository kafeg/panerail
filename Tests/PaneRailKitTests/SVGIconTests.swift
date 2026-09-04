import XCTest
@testable import PaneRailKit

final class SVGIconTests: XCTestCase {
    /// Shaped exactly like the icons Vivaldi stores.
    private let star = """
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" xmlns="http://www.w3.org/2000/svg">
      <path d="M8 0.74L9.73 6.27H15.5L10.92 9.71L12.72 15.26L8 11.83L3.28 15.26L5.08 9.71L0.5 6.27H6.27L8 0.74Z" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>
    """

    func testReadsTheViewBox() {
        XCTAssertEqual(SVGIconParser.parse(star)?.viewBox, CGRect(x: 0, y: 0, width: 16, height: 16))
    }

    func testProducesAPathInsideTheViewBox() throws {
        let icon = try XCTUnwrap(SVGIconParser.parse(star))
        let bounds = icon.path.boundingBox
        XCTAssertTrue(icon.viewBox.insetBy(dx: -0.5, dy: -0.5).contains(bounds), "\(bounds)")
    }

    func testFallsBackToTheDefaultViewBoxWhenAbsent() {
        let svg = #"<svg><path d="M0 0L4 4"/></svg>"#
        XCTAssertEqual(SVGIconParser.parse(svg)?.viewBox.width, 16)
    }

    func testReadsLineElements() throws {
        let svg = #"<svg viewBox="0 0 10 10"><line x1="1" y1="2" x2="9" y2="8"/></svg>"#
        let icon = try XCTUnwrap(SVGIconParser.parse(svg))
        XCTAssertEqual(icon.path.boundingBox.minX, 1, accuracy: 0.001)
        XCTAssertEqual(icon.path.boundingBox.maxY, 8, accuracy: 0.001)
    }

    func testCombinesEveryShapeInTheDocument() throws {
        let svg = """
        <svg viewBox="0 0 10 10">
          <path d="M0 0L2 2"/>
          <path d="M6 6L10 10"/>
          <line x1="0" y1="10" x2="10" y2="0"/>
        </svg>
        """
        let icon = try XCTUnwrap(SVGIconParser.parse(svg))
        XCTAssertEqual(icon.path.boundingBox, CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    func testHandlesEveryCommandVivaldiUses() throws {
        let svg = #"<svg viewBox="0 0 10 10"><path d="M1 1H9V9C9 9 5 9 1 9Z"/></svg>"#
        let icon = try XCTUnwrap(SVGIconParser.parse(svg))
        XCTAssertEqual(icon.path.boundingBox, CGRect(x: 1, y: 1, width: 8, height: 8))
    }

    func testHandlesRelativeCommands() throws {
        let absolute = try XCTUnwrap(SVGIconParser.parse(#"<svg viewBox="0 0 10 10"><path d="M1 1L5 1L5 5"/></svg>"#))
        let relative = try XCTUnwrap(SVGIconParser.parse(#"<svg viewBox="0 0 10 10"><path d="M1 1l4 0l0 4"/></svg>"#))
        XCTAssertEqual(absolute.path.boundingBox, relative.path.boundingBox)
    }

    /// Half-understanding a shape would draw something wrong; dropping it lets
    /// the row fall back to its plain marker.
    func testRejectsCommandsItCannotDraw() {
        XCTAssertNil(SVGIconParser.parse(#"<svg viewBox="0 0 10 10"><path d="M1 1A5 5 0 0 1 9 9"/></svg>"#))
    }

    func testRejectsDocumentsWithNoShapes() {
        XCTAssertNil(SVGIconParser.parse(#"<svg viewBox="0 0 16 16"></svg>"#))
        XCTAssertNil(SVGIconParser.parse("not svg at all"))
    }

    func testRendersATemplateImageOfTheRequestedSize() throws {
        let image = try XCTUnwrap(SVGIconRenderer().image(svg: star, side: 13))
        XCTAssertEqual(image.size, NSSize(width: 13, height: 13))
        XCTAssertTrue(image.isTemplate, "the rail tints it to match the row")
    }

    func testRenderingIsCached() throws {
        let renderer = SVGIconRenderer()
        let first = try XCTUnwrap(renderer.image(svg: star, side: 13))
        let second = try XCTUnwrap(renderer.image(svg: star, side: 13))
        XCTAssertTrue(first === second)
    }
}
