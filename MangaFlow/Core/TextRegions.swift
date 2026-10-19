import Foundation

struct TextDetection: Sendable {
    var rect: UnitRect
    var confidence: Double
    var kind: PageTextKind
}

/// Keep balloon geometry separate from reading crops and from individual text blocks.
enum TextRegions {
    static func suppressed(_ detections: [TextDetection]) -> [TextDetection] {
        var kept: [TextDetection] = []
        for item in detections.sorted(by: { $0.confidence > $1.confidence }) {
            guard item.rect.area > 0, item.confidence.isFinite else { continue }
            if kept.contains(where: {
                let intersection = item.rect.intersection($0.rect)
                return item.kind == $0.kind && (intersection / max(1e-9, item.rect.area + $0.rect.area - intersection) > 0.45 ||
                    intersection / min(item.rect.area, $0.rect.area) > 0.85)
            }) { continue }
            kept.append(item)
        }
        return kept
    }

    static func regions(_ detections: [TextDetection], fallback: [Detection], pageID: Int) -> [PageTextRegion] {
        let balloons = suppressed(detections).filter { $0.kind == .bubble }
        var items = balloons + suppressed(detections).filter { text in
            text.kind == .freeText && !balloons.contains { text.rect.intersection($0.rect) / text.rect.area > 0.5 }
        }
        // Existing panel model catches some stylized narration missed by the balloon model.
        // Require high confidence, and never create a second target inside a known balloon.
        for text in fallback where text.kind == 1 && text.confidence >= 0.5 && text.rect.area > 0.0001 && text.rect.area < 0.25 {
            if items.contains(where: { text.rect.intersection($0.rect) / text.rect.area > 0.45 }) { continue }
            items.append(.init(rect: text.rect, confidence: text.confidence, kind: .freeText))
        }
        return suppressed(items).enumerated().map { index, item in
            PageTextRegion(id: "\(pageID)-text-\(index)", rect: item.rect, kind: item.kind, confidence: item.confidence)
        }
    }
}
