import XCTest
import UIKit
@testable import MangaFlow

/// Explicit local review only: private pages and outputs stay outside the repository.
final class PanelReviewTests: XCTestCase {
    func testPrivateColumnReview() async throws {
        let root = URL(fileURLWithPath: "/tmp/mangaflow-310-review")
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("enabled").path) else {
            throw XCTSkip("Opt-in private column fixture absent")
        }
        let url = root.appendingPathComponent("page.jpg")
        let detector = LocalPanelDetector()
        let image = try PageImage.load(at: url, maxPixel: 1600)
        let detections = try await detector.detect(image: image)
        let expected = try JSONDecoder().decode([ReadingPanel].self, from: Data(contentsOf: root.appendingPathComponent("proposed/panels.json")))
        let panels = ContourRefiner.refine(image: image, panels: PanelLayout.readingPanels(detections, pageID: 15, rtl: true), texts: detections)
        XCTAssertEqual(panels.count, 2)
        let output = root.appendingPathComponent("integrated")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (index, pair) in zip(panels, expected).enumerated() {
            XCTAssertEqual(pair.0.rect, pair.1.rect, "Automatic grouping must match the reviewed preview")
            XCTAssertEqual(pair.0.contour, pair.1.contour)
            let crop = try PageImage.crop(at: url, rect: pair.0.rect, contour: pair.0.contour, targetWidth: 700)
            try XCTUnwrap(crop.pngData()).write(to: output.appendingPathComponent("\(index).png"))
        }
    }

    func testPrivateChapterReview() async throws {
        let root = URL(fileURLWithPath: "/tmp/mangaflow-panel-review")
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("enabled").path) else {
            throw XCTSkip("Opt-in private chapter review fixture absent")
        }
        let label = try String(contentsOf: root.appendingPathComponent("enabled"), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let output = root.appendingPathComponent(label)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let detector = LocalPanelDetector()
        var report: [[String: Any]] = []
        for page in 1...19 {
            let url = root.appendingPathComponent(String(format: "%05d.jpg", page))
            let image = try PageImage.load(at: url, maxPixel: 1600)
            let detections = try await detector.detect(image: image)
            let panels = ContourRefiner.refine(image: image, panels: PanelLayout.readingPanels(detections, pageID: page - 1, rtl: true), texts: detections)
            var entries: [[String: Any]] = []
            for (index, panel) in panels.enumerated() {
                let crop = try PageImage.crop(at: url, rect: panel.rect, contour: panel.contour, targetWidth: 700)
                try XCTUnwrap(crop.pngData()).write(to: output.appendingPathComponent("\(page)-\(index).png"))
                entries.append(try JSONSerialization.jsonObject(with: JSONEncoder().encode(panel)) as! [String: Any])
            }
            report.append(["page": page, "panels": entries, "detections": detections.map { d in
                ["x": d.rect.x, "y": d.rect.y, "width": d.rect.width, "height": d.rect.height, "confidence": d.confidence, "kind": Double(d.kind)]
            }])
            print("REVIEW \(label) page \(page): \(panels.count) panels, \(panels.filter { $0.contour != nil }.count) masks")
        }
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
    }
}
