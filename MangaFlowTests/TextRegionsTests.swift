import XCTest
import CoreML
import UIKit
@testable import MangaFlow

final class TextRegionsTests: XCTestCase {
    func testBubbleHitTakesPriorityAndPaddingDoesNotStealDrawingTaps() {
        let bubble = PageTextRegion(id: "bubble", rect: .init(x: 0.2, y: 0.2, width: 0.2, height: 0.15), kind: .bubble, confidence: 0.9)
        let free = PageTextRegion(id: "free", rect: .init(x: 0.25, y: 0.25, width: 0.05, height: 0.05), kind: .freeText, confidence: 0.8)
        XCTAssertEqual(PanelZoom.text(at: .init(x: 0.27, y: 0.27), in: [free, bubble])?.id, "bubble")
        XCTAssertNil(PanelZoom.text(at: .init(x: 0.195, y: 0.25), in: [bubble]))
        XCTAssertTrue(bubble.zoomRect.cgRect.contains(CGPoint(x: 0.195, y: 0.25)))
        let panel = ReadingPanel(id: "drawing", rect: .init(x: 0, y: 0, width: 0.8, height: 0.8), confidence: 0.9)
        XCTAssertEqual(PanelZoom.panel(at: .init(x: 0.6, y: 0.6), in: [panel])?.id, "drawing")
    }
    func testDuplicateSuppressionAndTextOutsideBubblesFallback() {
        let rect = UnitRect(x: 0.2, y: 0.2, width: 0.2, height: 0.2)
        let duplicate = TextDetection(rect: rect, confidence: 0.7, kind: .bubble)
        let main = TextDetection(rect: rect, confidence: 0.9, kind: .bubble)
        let inside = TextDetection(rect: .init(x: 0.25, y: 0.25, width: 0.1, height: 0.1), confidence: 0.8, kind: .freeText)
        let outside = Detection(rect: .init(x: 0.6, y: 0.6, width: 0.2, height: 0.1), confidence: 0.8, kind: 1)
        let regions = TextRegions.regions([duplicate, main, inside], fallback: [outside, .init(rect: rect, confidence: 0.9, kind: 1)], pageID: 7)
        XCTAssertEqual(regions.count, 2)
        XCTAssertEqual(regions[0].kind, .bubble)
        XCTAssertEqual(regions[1].kind, .freeText)
        XCTAssertEqual(regions[1].rect, outside.rect)
    }
    func testDecodeRawYOLOOutputUnletterboxesAndRejectsMalformedValues() throws {
        let array = try MLMultiArray(shape: [1, 6, 21504], dataType: .float32)
        for i in 0..<array.count { array[i] = 0 }
        func row(_ i: Int, _ values: [Double]) {
            for (channel, value) in values.enumerated() { array[[0, NSNumber(value: channel), NSNumber(value: i)]] = NSNumber(value: value) }
        }
        // Portrait page 800x1200: horizontal padding 170px, scale 1024/1200.
        row(0, [512, 512, 200, 100, 0.9, 0.1])
        row(1, [512, 512, 200, 100, 0.8, 0.1])
        row(2, [.nan, 512, 200, 100, 0.9, 0.1])
        row(3, [400, 300, -100, 100, 0.9, 0.1])
        row(4, [300, 800, 100, 80, 0.1, 0.7])
        let result = try LocalTextDetector.decode(array, width: 800, height: 1200)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].kind, .bubble)
        XCTAssertEqual(result[0].rect.midY, 0.5, accuracy: 0.001)
        XCTAssertEqual(result[0].rect.width, 200 / (1024.0 / 1200) / 800, accuracy: 0.001)
        XCTAssertEqual(result[1].kind, .freeText)
        XCTAssertThrowsError(try LocalTextDetector.decode(MLMultiArray(shape: [1, 3], dataType: .float32), width: 800, height: 1200))
    }
    func testNarrationLinesGroupIntoParagraphsWithoutJoiningNearbyColumns() {
        let lines = [Detection(rect: .init(x: 0.05, y: 0.1, width: 0.2, height: 0.05), confidence: 0.9, kind: 1),
                     Detection(rect: .init(x: 0.04, y: 0.16, width: 0.23, height: 0.05), confidence: 0.8, kind: 1),
                     Detection(rect: .init(x: 0.6, y: 0.16, width: 0.2, height: 0.05), confidence: 0.9, kind: 1),
                     Detection(rect: .init(x: 0.6, y: 0.4, width: 0.2, height: 0.05), confidence: 0.9, kind: 1)]
        let groups = NarrationDetector.grouped(lines)
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups[0].rect.height, 0.11, accuracy: 0.001)
        XCTAssertEqual(groups[0].confidence, 0.8)
    }
    func testRegionsPersistAndLegacyManifestRemainsReadable() throws {
        var page = MangaPage(id: 0, filename: "page.jpg")
        page.textRegions = [.init(id: "speech", rect: .init(x: 0.9, y: 0.9, width: 0.1, height: 0.1), kind: .bubble, confidence: 0.9)]
        let data = try JSONEncoder().encode(page)
        XCTAssertEqual(try JSONDecoder().decode(MangaPage.self, from: data).textRegions?.first?.kind, .bubble)
        XCTAssertEqual(page.textRegions?.first?.zoomRect.maxX, 1)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "textRegions")
        XCTAssertNil(try JSONDecoder().decode(MangaPage.self, from: JSONSerialization.data(withJSONObject: legacy)).textRegions)
    }
    func testPrivateChapterConversionWithBothBundledModels() async throws {
        let cbz = URL(fileURLWithPath: "/private/tmp/mangaflow-bubble-review.cbz")
        guard FileManager.default.fileExists(atPath: cbz.path) else { throw XCTSkip("Opt-in local chapter absent") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DocumentStore(root: root)
        let doc = try store.importArchive(cbz)
        let converted = try await ConversionEngine(store: store).convert(doc) { _ in }
        XCTAssertTrue(converted.complete)
        XCTAssertTrue(converted.pages.allSatisfy { $0.textRegions != nil })
        XCTAssertGreaterThan(converted.pages.flatMap { $0.textRegions ?? [] }.filter { $0.kind == .bubble }.count, 20)
        XCTAssertGreaterThan(converted.pages.flatMap { $0.textRegions ?? [] }.filter { $0.kind == .freeText }.count, 0)
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        try encoder.encode(converted).write(to: URL(fileURLWithPath: "/private/tmp/mangaflow-bubble-native.json"))
    }
}
