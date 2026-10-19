import XCTest
@testable import MangaFlow

final class PanelZoomTests: XCTestCase {
    private func panel(_ id: String, _ rect: UnitRect) -> ReadingPanel {
        ReadingPanel(id: id, rect: rect, confidence: 0.9)
    }
    func testHitTestingChoosesIndividualInsetAndIgnoresGutters() {
        let left = panel("left", .init(x: 0.02, y: 0.02, width: 0.44, height: 0.8))
        let right = panel("right", .init(x: 0.54, y: 0.02, width: 0.44, height: 0.8))
        let inset = panel("inset", .init(x: 0.1, y: 0.1, width: 0.2, height: 0.2))
        XCTAssertEqual(PanelZoom.panel(at: .init(x: 0.2, y: 0.2), in: [left, right, inset])?.id, "inset")
        XCTAssertEqual(PanelZoom.panel(at: .init(x: 0.8, y: 0.2), in: [left, right])?.id, "right")
        XCTAssertNil(PanelZoom.panel(at: .init(x: 0.5, y: 0.5), in: [left, right]))
        XCTAssertNil(PanelZoom.panel(at: .init(x: 0.5, y: 0.5), in: [panel("fallback", .full)]))
    }
    func testAngledContourRejectsNeighbourButKeepsProtectedDialogue() {
        var item = panel("angle", .init(x: 0, y: 0, width: 1, height: 0.7))
        item.contour = .init(points: [.init(x: 0, y: 0.5), .init(x: 1, y: 0), .init(x: 1, y: 0.7), .init(x: 0, y: 0.7)],
                             protectedRects: [.init(x: 0.1, y: 0.1, width: 0.1, height: 0.1)])
        XCTAssertNil(PanelZoom.panel(at: .init(x: 0.3, y: 0.1), in: [item]))
        XCTAssertNotNil(PanelZoom.panel(at: .init(x: 0.15, y: 0.15), in: [item]))
        XCTAssertNotNil(PanelZoom.panel(at: .init(x: 0.8, y: 0.5), in: [item]))
    }
    func testTransformCentersCaseInVisiblePageSliceAndCapsMagnification() {
        let item = panel("case", .init(x: 0.5, y: 0.4, width: 0.4, height: 0.2))
        let visible = CGRect(x: 0, y: 300, width: 400, height: 600)
        let t = PanelZoom.transform(for: item, size: .init(width: 400, height: 1200), visible: visible)
        XCTAssertEqual(t.scale, 2.5)
        XCTAssertEqual(0.7 * 400 * t.scale + t.x, visible.midX, accuracy: 0.001)
        XCTAssertEqual(0.5 * 1200 * t.scale + t.y, visible.midY, accuracy: 0.001)
        XCTAssertEqual(PanelZoom.transform(for: panel("tiny", .init(x: 0.1, y: 0.1, width: 0.05, height: 0.05)), size: .init(width: 400, height: 1200), visible: visible).scale, 4)
    }
    func testIndividualGeometryRoundTripsAndOldPagesStillDecode() throws {
        var page = MangaPage(id: 0, filename: "page.jpg")
        page.panels = [panel("reading-strip", .full)]
        page.zoomPanels = [panel("case", .init(x: 0, y: 0, width: 0.5, height: 0.5))]
        let restored = try JSONDecoder().decode(MangaPage.self, from: JSONEncoder().encode(page))
        XCTAssertEqual(restored.zoomPanels?.first?.id, "case")
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(page)) as? [String: Any])
        legacy.removeValue(forKey: "zoomPanels")
        XCTAssertNil(try JSONDecoder().decode(MangaPage.self, from: JSONSerialization.data(withJSONObject: legacy)).zoomPanels)
    }
}
