import XCTest
import UIKit
@testable import MangaFlow

final class ContourTests: XCTestCase {
    private func render(_ draw: (UIGraphicsImageRendererContext) -> Void) -> CGImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 500, height: 600), format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 500, height: 600))
            draw(context)
        }.cgImage!
    }
    func testGrayImageKeepsTopLeftCoordinates() throws {
        let image = render { context in
            UIColor.black.setFill(); context.fill(CGRect(x: 0, y: 0, width: 80, height: 60))
        }
        let page = try XCTUnwrap(ContourRefiner.GrayPage(image: image))
        XCTAssertLessThan(page.white(10, 10), 0.1)
        XCTAssertGreaterThan(page.white(10, 590), 0.9)
    }
    func testSlantedBordersProducePolygonWithoutWarping() throws {
        let image = render { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 50, y: 60)); path.addLine(to: CGPoint(x: 450, y: 120))
            path.addLine(to: CGPoint(x: 450, y: 480)); path.addLine(to: CGPoint(x: 50, y: 420)); path.close()
            UIColor.lightGray.setFill(); path.fill()
            UIColor.black.setStroke(); path.lineWidth = 4; path.stroke()
        }
        let gray = try XCTUnwrap(ContourRefiner.GrayPage(image: image))
        let rect = UnitRect(x: 0.1, y: 0.1, width: 0.8, height: 0.7)
        let result = try XCTUnwrap(ContourRefiner.contour(in: gray, rect: rect))
        XCTAssertGreaterThanOrEqual(result.points.count, 4)
        XCTAssertLessThan(ContourRefiner.area(result.points), rect.area * 0.92)
        XCTAssertGreaterThan(ContourRefiner.area(result.points), rect.area * 0.75)
        let topRight = result.points.filter { $0.x > 0.89 }.map(\.y).min()!
        let topLeft = result.points.filter { $0.x < 0.11 }.map(\.y).min()!
        XCTAssertEqual(topRight - topLeft, 0.1, accuracy: 0.02)
    }
    func testUnframedAndAxisAlignedImagesKeepRectangle() throws {
        let plain = try XCTUnwrap(ContourRefiner.GrayPage(image: render { _ in }))
        let rect = UnitRect(x: 0.1, y: 0.1, width: 0.8, height: 0.7)
        XCTAssertNil(ContourRefiner.contour(in: plain, rect: rect))
        let framed = render { context in
            UIColor.black.setStroke(); context.cgContext.setLineWidth(4)
            context.cgContext.stroke(CGRect(x: 50, y: 60, width: 400, height: 420))
        }
        XCTAssertNil(ContourRefiner.contour(in: try XCTUnwrap(ContourRefiner.GrayPage(image: framed)), rect: rect))
    }
    func testMaskRemovesNeighbourAndRetainsProtectedText() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let source = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100), format: format).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }.cgImage!
        let contour = PanelContour(points: [PagePoint(x: 0, y: 0), PagePoint(x: 1, y: 0.8),
                                             PagePoint(x: 1, y: 1), PagePoint(x: 0, y: 1)],
                                   protectedRects: [UnitRect(x: 0.8, y: 0.05, width: 0.1, height: 0.1)])
        let masked = PageImage.masked(source, sourceWidth: 100, sourceHeight: 100,
                                     cropBox: CGRect(x: 0, y: 0, width: 100, height: 100), contour: contour)
        let image = try XCTUnwrap(masked.cgImage)
        XCTAssertEqual(image.width, 100); XCTAssertEqual(image.height, 100)
        var pixels = [UInt8](repeating: 0, count: 100 * 100 * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: 100, height: 100, bitsPerComponent: 8,
                                              bytesPerRow: 400, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 100, height: 100))
        func alpha(_ x: Int, _ y: Int) -> UInt8 { pixels[(y * 100 + x) * 4 + 3] }
        XCTAssertEqual(alpha(95, 10), 0, "Neighbouring artwork must become transparent")
        XCTAssertEqual(alpha(85, 10), 255, "Protected dialogue must remain visible outside the polygon")
        XCTAssertEqual(alpha(20, 70), 255, "Panel artwork must remain opaque")
    }
    func testLegacyPanelDecodingAndContourRoundTrip() throws {
        let legacy = Data(#"{"id":"0-0","rect":{"x":0,"y":0,"width":1,"height":1},"confidence":0.9}"#.utf8)
        var panel = try JSONDecoder().decode(ReadingPanel.self, from: legacy)
        XCTAssertNil(panel.contour)
        panel.contour = PanelContour(points: [PagePoint(x: 0, y: 0), PagePoint(x: 1, y: 0.5), PagePoint(x: 0, y: 1)],
                                     protectedRects: [UnitRect(x: 0.5, y: 0.1, width: 0.1, height: 0.1)])
        let decoded = try JSONDecoder().decode(ReadingPanel.self, from: JSONEncoder().encode(panel))
        XCTAssertEqual(decoded.contour, panel.contour)
    }
    func testOlderConversionIsUpgradedAndCheckpointed() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DocumentStore(root: root)
        var page = MangaPage(id: 0, filename: "page.png")
        page.processed = true
        page.panels = [ReadingPanel(id: "0-0", rect: .full, confidence: 1)]
        var doc = MangaDocument(id: UUID(), title: "Old conversion", pages: [page])
        doc.engineVersion = "yolo26-fp32-layout-v1"
        try store.save(doc)
        let data = UIImage(cgImage: render { _ in }).pngData()!
        try data.write(to: store.pageURL(doc, page))
        let updated = try await ConversionEngine(store: store).convert(doc) { _ in }
        XCTAssertTrue(updated.complete)
        XCTAssertEqual(updated.engineVersion, MangaDocument.engine)
        XCTAssertGreaterThan(updated.pages[0].milliseconds, 0)
        XCTAssertEqual(try store.loadAll()[0].engineVersion, MangaDocument.engine)
    }
}
