import XCTest
import UIKit
import ZIPFoundation
@testable import MangaFlow

final class PipelineTests: XCTestCase {
    func box(_ x: Double, _ y: Double, _ w: Double, _ h: Double, score: Double = 0.9, kind: Int = 0) -> Detection {
        Detection(rect: UnitRect(x: x, y: y, width: w, height: h), confidence: score, kind: kind)
    }
    func testRTLAndLTRGrid() {
        let detections = [box(0.05, 0.05, 0.4, 0.4), box(0.55, 0.05, 0.4, 0.4),
                          box(0.05, 0.55, 0.4, 0.4), box(0.55, 0.55, 0.4, 0.4)]
        XCTAssertEqual(PanelLayout.ordered(detections, rtl: true).map(\.rect.x), [0.55, 0.05, 0.55, 0.05])
        XCTAssertEqual(PanelLayout.ordered(detections, rtl: false).map(\.rect.x), [0.05, 0.55, 0.05, 0.55])
    }
    func testTallPanelAlongsideStackedPanels() {
        let tall = box(0.55, 0.05, 0.4, 0.9)
        let top = box(0.05, 0.05, 0.4, 0.4)
        let bottom = box(0.05, 0.55, 0.4, 0.4)
        XCTAssertEqual(PanelLayout.ordered([bottom, top, tall], rtl: true).map(\.rect), [tall.rect, top.rect, bottom.rect])
    }
    func testDuplicatesAndInvalidBoxesAreRemoved() {
        let valid = box(0.1, 0.1, 0.6, 0.6)
        let items = [valid, box(0.102, 0.1, 0.6, 0.6, score: 0.8), box(2, 2, 0.1, 0.1), box(0, 0, 0.001, 0.001), box(.nan, 0, 0.5, 0.5)]
        XCTAssertEqual(PanelLayout.normalized(items).count, 1)
    }
    func testInsetPanelIsNotSuppressedAsDuplicate() {
        let large = box(0.05, 0.05, 0.9, 0.9)
        let inset = box(0.6, 0.6, 0.25, 0.25)
        XCTAssertEqual(PanelLayout.normalized([large, inset]).count, 2)
    }
    func testFullWidthRowsPreserveEntirePageInBothReadingDirections() {
        let rows = [box(0.04, 0.04, 0.92, 0.27), box(0.06, 0.32, 0.90, 0.30),
                    box(0.05, 0.61, 0.90, 0.34), box(0.3, 0.2, 0.2, 0.1, kind: 1)]
        for rtl in [true, false] {
            let panels = PanelLayout.readingPanels(rows, pageID: 12, rtl: rtl)
            XCTAssertEqual(panels.count, 1)
            XCTAssertEqual(panels.first?.rect, .full)
            XCTAssertEqual(panels.first?.id, "12-0")
            XCTAssertNil(panels.first?.contour)
        }
    }
    func testFullWidthRuleRejectsSideBySideAndInsetPanels() {
        for rows in [
            [box(0.04, 0.04, 0.92, 0.4), box(0.04, 0.48, 0.44, 0.45), box(0.52, 0.48, 0.44, 0.45)],
            [box(0.04, 0.04, 0.92, 0.92), box(0.6, 0.6, 0.3, 0.25)],
            [box(0.04, 0.04, 0.92, 0.8), box(0.04, 0.3, 0.92, 0.3)]
        ] {
            XCTAssertEqual(PanelLayout.readingPanels(rows, pageID: 0, rtl: true).count, rows.count)
        }
    }
    func testNarrowRowsStillCropAndEmptyDetectionsStillFallBackInEngine() {
        let narrow = [box(0.2, 0.05, 0.6, 0.4), box(0.2, 0.55, 0.6, 0.4)]
        XCTAssertEqual(PanelLayout.readingPanels(narrow, pageID: 0, rtl: true).count, 2)
        XCTAssertTrue(PanelLayout.readingPanels([], pageID: 0, rtl: true).isEmpty)
        XCTAssertTrue(PanelLayout.readingPanels([box(0.1, 0.1, 0.8, 0.04, kind: 1)], pageID: 0, rtl: true).isEmpty)
        XCTAssertEqual(PanelLayout.readingPanels([box(0.04, 0.05, 0.92, 0.9)], pageID: 0, rtl: true).first?.rect, .full)
    }
    func testSlantedFullWidthBandsCanOverlapWithoutRepeatingArtwork() {
        let rows = [box(0.02, 0, 0.98, 0.69), box(0.04, 0.42, 0.95, 0.30),
                    box(0.045, 0.56, 0.94, 0.44)]
        XCTAssertEqual(PanelLayout.readingPanels(rows, pageID: 9, rtl: true).map(\.rect), [.full])
    }
    func testMixedPageKeepsTopColumnsAndGroupsFollowingFullWidthBands() {
        let rows = [box(0, 0, 0.42, 0.26), box(0.38, 0, 0.58, 0.25),
                    box(0, 0.13, 0.95, 0.26), box(0, 0.31, 0.96, 0.29),
                    box(0, 0.49, 0.97, 0.26), box(0, 0.65, 0.96, 0.35)]
        for rtl in [true, false] {
            let result = PanelLayout.readingPanels(rows, pageID: 12, rtl: rtl)
            XCTAssertEqual(result.count, 3)
            XCTAssertGreaterThan(result[2].rect.width, 0.97)
            XCTAssertLessThan(result[2].rect.y, 0.14)
            XCTAssertEqual(result[2].rect.maxY, 1, accuracy: 0.001)
            XCTAssertEqual(result[0].rect.x > 0.3, rtl)
        }
    }
    func testInsetPanelPreventsMergingItsSurroundingBand() {
        let rows = [box(0.02, 0, 0.96, 0.30), box(0.02, 0.25, 0.96, 0.75),
                    box(0.02, 0.75, 0.25, 0.25)]
        XCTAssertEqual(PanelLayout.readingPanels(rows, pageID: 0, rtl: true).count, 3)
    }
    func testWideNarrationOutsideFramesIsPreservedWithoutDuplicatingInsideText() {
        let rows = [box(0.1, 0.10, 0.8, 0.35), box(0.1, 0.55, 0.35, 0.35),
                    box(0.55, 0.55, 0.35, 0.35), box(0.2, 0.02, 0.6, 0.03, kind: 1),
                    box(0.2, 0.20, 0.6, 0.03, kind: 1)]
        let result = PanelLayout.readingPanels(rows, pageID: 0, rtl: true)
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result[0].rect.width, 1)
        XCTAssertLessThan(result[0].rect.y, 0.02)
    }
    func testLetterboxPortraitAndLandscape() {
        let portrait = LocalPanelDetector.unletterbox(x1: 160, y1: 0, x2: 480, y2: 640, width: 1000, height: 2000)
        XCTAssertEqual(portrait.x, 0, accuracy: 0.00001)
        XCTAssertEqual(portrait.width, 1, accuracy: 0.00001)
        XCTAssertEqual(portrait.height, 1, accuracy: 0.00001)
        let landscape = LocalPanelDetector.unletterbox(x1: 0, y1: 160, x2: 640, y2: 480, width: 2000, height: 1000)
        XCTAssertEqual(landscape, .full)
    }
    func testDialogueExtendsCropWithoutLeavingPage() {
        let panels = PanelLayout.readingPanels([box(0.1, 0.1, 0.4, 0.5), box(0.4, 0.2, 0.2, 0.1, kind: 1)], pageID: 0, rtl: true)
        XCTAssertEqual(panels.count, 1)
        XCTAssertGreaterThanOrEqual(panels[0].rect.maxX, 0.6)
        XCTAssertLessThanOrEqual(panels[0].rect.maxX, 1)
    }
    func testArchivePathFilteringAndNaturalOrder() {
        XCTAssertFalse(DocumentStore.supportedPath("../evil.jpg"))
        XCTAssertFalse(DocumentStore.supportedPath("/absolute.jpg"))
        XCTAssertFalse(DocumentStore.supportedPath("__MACOSX/._1.jpg"))
        XCTAssertFalse(DocumentStore.supportedPath("folder/../evil.png"))
        XCTAssertTrue(DocumentStore.supportedPath("chapter/page10.PNG"))
        XCTAssertEqual(["10.jpg", "2.jpg", "1.jpg"].sorted(by: DocumentStore.naturalOrder), ["1.jpg", "2.jpg", "10.jpg"])
    }
    func testArchiveImportPersistsAndRejectsInvalidArchive() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let imageURL = root.appendingPathComponent("page.png")
        try syntheticPage().pngData()!.write(to: imageURL)
        let cbz = root.appendingPathComponent("demo.cbz")
        let archive = try Archive(url: cbz, accessMode: .create)
        for name in ["10.png", "2.png", "1.png"] {
            let data = try Data(contentsOf: imageURL)
            try archive.addEntry(with: name, type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate) { position, size in
                data.subdata(in: Int(position)..<min(data.count, Int(position) + size))
            }
        }
        let store = DocumentStore(root: root.appendingPathComponent("library"))
        let doc = try store.importArchive(cbz)
        XCTAssertEqual(doc.pages.count, 3)
        XCTAssertFalse(doc.complete)
        XCTAssertEqual(try store.loadAll().first?.id, doc.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.pageURL(doc, doc.pages[0]).path))
        let corrupt = root.appendingPathComponent("broken.cbz")
        try Data("broken".utf8).write(to: corrupt)
        XCTAssertThrowsError(try store.importArchive(corrupt))
    }
    func testBundledDetectorAndResumablePipeline() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DocumentStore(root: root)
        var doc = MangaDocument(id: UUID(), title: "Pipeline test", pages: [MangaPage(id: 0, filename: "0.png"), MangaPage(id: 1, filename: "1.png")])
        try store.save(doc)
        let data = syntheticPage().pngData()!
        for page in doc.pages { try data.write(to: store.pageURL(doc, page)) }
        let engine = ConversionEngine(store: store)
        doc = try await engine.convert(doc) { _ in }
        XCTAssertTrue(doc.complete)
        XCTAssertGreaterThanOrEqual(doc.panelCount, 2)
        XCTAssertTrue(doc.pages.allSatisfy { $0.width == 800 && $0.height == 1200 })
        let firstDuration = doc.pages[0].milliseconds
        let reloaded = try store.loadAll()[0]
        let resumed = try await engine.convert(reloaded) { _ in XCTFail("Completed pages must not be processed again") }
        XCTAssertEqual(resumed.pages[0].milliseconds, firstDuration)
    }
    func testCancellationPreservesCheckpointAndResumesRemainingPages() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DocumentStore(root: root)
        let pages = (0..<3).map { MangaPage(id: $0, filename: "\($0).png") }
        let doc = MangaDocument(id: UUID(), title: "Cancellation", pages: pages)
        try store.save(doc)
        let data = syntheticPage().pngData()!
        for page in pages { try data.write(to: store.pageURL(doc, page)) }
        let engine = ConversionEngine(store: store)
        let checkpoint = expectation(description: "First page checkpoint")
        let task = Task {
            try await engine.convert(doc) { value in
                if value.processedCount == 1 {
                    checkpoint.fulfill()
                    try? await Task.sleep(for: .seconds(10))
                }
            }
        }
        await fulfillment(of: [checkpoint], timeout: 10)
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        let partial = try store.loadAll()[0]
        XCTAssertEqual(partial.processedCount, 1)
        let milliseconds = partial.pages[0].milliseconds
        let resumed = try await engine.convert(partial) { _ in }
        XCTAssertTrue(resumed.complete)
        XCTAssertEqual(resumed.pages[0].milliseconds, milliseconds)
    }
    private func syntheticPage() -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 800, height: 1200), format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 800, height: 1200))
            UIColor.black.setStroke(); context.cgContext.setLineWidth(8)
            for rect in [CGRect(x: 35, y: 35, width: 350, height: 500), CGRect(x: 415, y: 35, width: 350, height: 500), CGRect(x: 35, y: 565, width: 730, height: 600)] {
                context.cgContext.stroke(rect)
                context.cgContext.strokeEllipse(in: rect.insetBy(dx: 65, dy: 120))
            }
        }
    }
}
