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
        // Slanted full-width bands have overlapping bounding boxes. What matters is
        // that both their top and bottom advance down the page; a nested panel
        // still fails this test. Keeping the original also avoids duplicating a
        // spurious full-width detection along a diagonal gutter.
        return zip(rows, rows.dropFirst()).allSatisfy { upper, lower in
            lower.rect.y - upper.rect.y > 0.02 &&
                lower.rect.maxY - upper.rect.maxY > 0.02
        }
    }

    /// Merge a vertical run only when a separate tall neighbour establishes a
    /// column layout. A regular grid must keep its row-by-row reading order.
    private static func groupedColumns(_ input: [Detection]) -> [Detection] {
        // Bounding boxes on either side of a slanted divider can overlap. Build
        // candidate columns geometrically before applying RTL/LTR ordering.
        var columns: [[Detection]] = []
        for panel in input.sorted(by: { $0.rect.y == $1.rect.y ? $0.rect.x < $1.rect.x : $0.rect.y < $1.rect.y }) {
            let match = columns.firstIndex { column in
                let run = column + [panel]
                let left = run.map { $0.rect.x }, right = run.map { $0.rect.maxX }
                let width = right.max()! - left.min()!
                return left.max()! - left.min()! <= width * 0.10 &&
                    right.max()! - right.min()! <= width * 0.10
            }
            if let match { columns[match].append(panel) } else { columns.append([panel]) }
        }
        let panels = columns.flatMap { $0 }
        var result: [Detection] = []
        var start = 0
        while start < panels.count {
            var end = start + 1
            var bounds = panels[start].rect.cgRect
            var acceptedEnd = end
            var acceptedBounds = bounds
            while end < panels.count {
                let previous = panels[end - 1].rect
                let next = panels[end].rect
                let union = bounds.union(next.cgRect)
                let width = union.width
                let run = Array(panels[start...end])
                let lefts = run.map { $0.rect.x }, rights = run.map { $0.rect.maxX }
                guard next.y - previous.y > 0.02, next.maxY - previous.maxY > 0.02,
                      next.y - previous.maxY < 0.10,
                      lefts.max()! - lefts.min()! <= width * 0.10,
                      rights.max()! - rights.min()! <= width * 0.10 else { break }
                let rect = UnitRect(union)
                let outside = panels.indices.filter { $0 < start || $0 > end }
                let anchors = outside.filter { index in
                    let other = panels[index].rect
                    let horizontalOverlap = max(0, min(other.maxX, rect.maxX) - max(other.x, rect.x))
                    return horizontalOverlap <= min(other.width, rect.width) * 0.15 &&
                        other.y <= rect.y + 0.06 && other.maxY >= rect.maxY - 0.06 &&
                        other.height >= rect.height * 0.80
                }
                if !anchors.isEmpty && outside.allSatisfy({ index in
                    anchors.contains(index) || rect.intersection(panels[index].rect) < panels[index].rect.area * 0.20
                }) {
                    acceptedEnd = end + 1
                    acceptedBounds = union
                }
                bounds = union
                end += 1
            }
            result.append(Detection(rect: UnitRect(acceptedBounds),
                                    confidence: panels[start..<acceptedEnd].map(\.confidence).min() ?? 0, kind: 0))
            start = acceptedEnd
        }
        return result
    }

    static func readingPanels(_ detections: [Detection], pageID: Int, rtl: Bool) -> [ReadingPanel] {
        let panels = ordered(groupedColumns(normalized(detections)), rtl: rtl)
        guard !panels.isEmpty else { return [] }
        // Already a vertical reading flow: preserve artwork, gutters and page margins.
        if isFullWidthStack(panels) {
            return [ReadingPanel(id: "\(pageID)-0", rect: .full,
                                 confidence: panels.map(\.confidence).min() ?? 0)]
        }
        // Preserve consecutive full-width bands inside a mixed page as one strip.
        // Narrow panels (including inset panels) always break a run.
        var groups: [[Detection]] = []
        let containsInset: (Detection) -> Bool = { wide in
            panels.contains { other in
                other.rect.width < 0.80 && other.rect.area < wide.rect.area &&
                    wide.rect.intersection(other.rect) > other.rect.area * 0.65
            }
        }
        for panel in panels {
            if let previous = groups.last?.last,
               !containsInset(previous), !containsInset(panel),
               isFullWidthStack([previous, panel]) {
                groups[groups.count - 1].append(panel)
            } else {
                groups.append([panel])
            }
        }
        var grouped = groups.map { group -> Detection in
            let rect = group.dropFirst().reduce(group[0].rect.cgRect) { $0.union($1.rect.cgRect) }
            return Detection(rect: UnitRect(rect), confidence: group.map(\.confidence).min() ?? 0, kind: 0)
        }
        // Wide narration outside any detected frame is part of the page too.
        // Keep it as a strip rather than silently dropping headers or footnotes.
        for text in detections where text.kind == 1 && text.confidence >= 0.30 && text.rect.width >= 0.45 && text.rect.area > 0 {
            guard grouped.allSatisfy({ $0.rect.intersection(text.rect) / max(text.rect.area, 0.000001) < 0.10 }) else { continue }
            let r = text.rect.padded(0.006)
            grouped.append(Detection(rect: UnitRect(x: 0, y: r.y, width: 1, height: r.height), confidence: text.confidence, kind: 0))
        }
        grouped = ordered(grouped, rtl: rtl)
        let texts = detections.filter { $0.kind == 1 && $0.confidence >= 0.35 && $0.rect.area > 0 }
        var crops = grouped.map { $0.rect.padded(0.008) }
        // Assign each text to its strongest overlapping panel, then preserve its full box.
        for text in texts {
            let candidates = grouped.enumerated().map { ($0.offset, $0.element.rect.intersection(text.rect) / text.rect.area) }
            if let best = candidates.max(by: { $0.1 < $1.1 }), best.1 > 0.25 {
                crops[best.0] = UnitRect(crops[best.0].cgRect.union(text.rect.padded(0.005).cgRect)).clamped()
            }
        }
        return grouped.enumerated().map { index, panel in
            ReadingPanel(id: "\(pageID)-\(index)", rect: crops[index], confidence: panel.confidence)
        }
    }
}
