import Foundation

enum PanelLayout {
    static func normalized(_ detections: [Detection]) -> [Detection] {
        var kept: [Detection] = []
        for var item in detections.filter({ $0.kind == 0 && $0.confidence >= 0.30 })
            .sorted(by: { $0.confidence > $1.confidence }) {
            guard [item.rect.x, item.rect.y, item.rect.width, item.rect.height].allSatisfy(\.isFinite) else { continue }
            item.rect = item.rect.clamped()
            guard item.rect.area > 0.008, item.rect.width > 0.025, item.rect.height > 0.025 else { continue }
            guard !kept.contains(where: {
                let overlap = item.rect.intersection($0.rect)
                let union = item.rect.area + $0.rect.area - overlap
                return overlap / max(union, 0.000001) > 0.65
            }) else { continue }
            kept.append(item)
        }
        return kept
    }

    /// XY-cut: horizontal gutters define bands; vertical gutters define columns inside them.
    static func ordered(_ panels: [Detection], rtl: Bool) -> [Detection] {
        guard panels.count > 1 else { return panels }
        for horizontal in [true, false] {
            let sorted = panels.sorted {
                horizontal ? $0.rect.y < $1.rect.y : $0.rect.x < $1.rect.x
            }
            var end = horizontal ? sorted[0].rect.maxY : sorted[0].rect.maxX
            var cuts: [(Int, Double)] = []
            for i in 1..<sorted.count {
                let start = horizontal ? sorted[i].rect.y : sorted[i].rect.x
                if start - end > -0.008 { cuts.append((i, start - end)) }
                end = max(end, horizontal ? sorted[i].rect.maxY : sorted[i].rect.maxX)
            }
            if let cut = cuts.max(by: { $0.1 < $1.1 }) {
                let first = ordered(Array(sorted[..<cut.0]), rtl: rtl)
                let second = ordered(Array(sorted[cut.0...]), rtl: rtl)
                return !horizontal && rtl ? second + first : first + second
            }
        }
        // Stable fallback for overlapping / diagonal layouts. Never use a non-transitive comparator.
        var remaining = panels.sorted { $0.rect.y == $1.rect.y ? $0.rect.x < $1.rect.x : $0.rect.y < $1.rect.y }
        var result: [Detection] = []
        while let top = remaining.first {
            let bandLimit = top.rect.y + min(top.rect.height * 0.35, 0.07)
            let band = remaining.filter { $0.rect.y <= bandLimit }.sorted {
                rtl ? $0.rect.midX > $1.rect.midX : $0.rect.midX < $1.rect.midX
            }
            result += band
            remaining.removeAll { $0.rect.y <= bandLimit }
        }
        return result
    }

    /// Use unpadded detections so text expansion cannot hide a narrow or inset panel.
    private static func isFullWidthStack(_ panels: [Detection]) -> Bool {
        guard !panels.isEmpty else { return false }
        // Allow up to 8% page margin per edge, with only small differences between rows.
        guard panels.allSatisfy({ $0.rect.x <= 0.08 && $0.rect.maxX >= 0.92 }) else { return false }
        let leftEdges = panels.map { $0.rect.x }
        let rightEdges = panels.map { $0.rect.maxX }
        guard (leftEdges.max()! - leftEdges.min()!) <= 0.04,
              (rightEdges.max()! - rightEdges.min()!) <= 0.04 else { return false }
        let rows = panels.sorted { $0.rect.y < $1.rect.y }
        // Slight overlap is allowed for detector noise / slanted borders, never nested rows.
        return zip(rows, rows.dropFirst()).allSatisfy { upper, lower in
            let overlap = upper.rect.maxY - lower.rect.y
            return lower.rect.y > upper.rect.y &&
                overlap <= min(0.02, min(upper.rect.height, lower.rect.height) * 0.10)
        }
    }

    static func readingPanels(_ detections: [Detection], pageID: Int, rtl: Bool) -> [ReadingPanel] {
        let panels = ordered(normalized(detections), rtl: rtl)
        // Already a vertical reading flow: preserve artwork, gutters and page margins.
        if isFullWidthStack(panels) {
            return [ReadingPanel(id: "\(pageID)-0", rect: .full,
                                 confidence: panels.map(\.confidence).min() ?? 0)]
        }
        let texts = detections.filter { $0.kind == 1 && $0.confidence >= 0.35 && $0.rect.area > 0 }
        var crops = panels.map { $0.rect.padded(0.008) }
        // Assign each text to its strongest overlapping panel, then preserve its full box.
        for text in texts {
            let candidates = panels.enumerated().map { ($0.offset, $0.element.rect.intersection(text.rect) / text.rect.area) }
            if let best = candidates.max(by: { $0.1 < $1.1 }), best.1 > 0.25 {
                crops[best.0] = UnitRect(crops[best.0].cgRect.union(text.rect.padded(0.005).cgRect)).clamped()
            }
        }
        return panels.enumerated().map { index, panel in
            ReadingPanel(id: "\(pageID)-\(index)", rect: crops[index], confidence: panel.confidence)
        }
    }
}
