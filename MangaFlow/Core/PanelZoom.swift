import Foundation
import CoreGraphics

enum PanelZoom {
    struct Transform: Equatable {
        let scale: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    static func text(at point: CGPoint, in regions: [PageTextRegion]) -> PageTextRegion? {
        regions.filter { $0.rect.cgRect.contains(point) }.min {
            if $0.kind != $1.kind { return $0.kind == .bubble }
            return $0.rect.area < $1.rect.area
        }
    }

    static func panel(at point: CGPoint, in panels: [ReadingPanel]) -> ReadingPanel? {
        panels.filter { panel in
            guard panel.rect.area < 0.94, panel.rect.cgRect.contains(point) else { return false }
            guard let contour = panel.contour, contour.points.count >= 3 else { return true }
            if contour.protectedRects.contains(where: { $0.cgRect.contains(point) }) { return true }
            let path = CGMutablePath()
            path.move(to: CGPoint(x: contour.points[0].x, y: contour.points[0].y))
            for p in contour.points.dropFirst() { path.addLine(to: CGPoint(x: p.x, y: p.y)) }
            path.closeSubpath()
            return path.contains(point)
        }.min {
            // Prefer an inset panel to its enclosing frame; confidence breaks ties.
            $0.rect.area == $1.rect.area ? $0.confidence > $1.confidence : $0.rect.area < $1.rect.area
        }
    }

    /// Keep dialogues in their individual case before moving to the next case.
    /// Unassigned captions become standalone blocks instead of disappearing.
    static func orderedText(_ regions: [PageTextRegion], panels: [ReadingPanel], rtl: Bool) -> [PageTextRegion] {
        let valid = regions.filter { $0.rect.area > 0 && [$0.rect.x, $0.rect.y, $0.rect.width, $0.rect.height].allSatisfy(\.isFinite) }
        let cases = panels.filter { $0.rect.area > 0 && $0.rect.area < 0.94 }
        var groups = cases.map { _ in [PageTextRegion]() }
        var blocks = cases.map { $0.rect }
        for region in valid {
            let candidates = cases.indices.filter { region.rect.intersection(cases[$0].rect) / region.rect.area >= 0.3 }
            let owner = candidates.sorted {
                let a = region.rect.intersection(cases[$0].rect) / region.rect.area
                let b = region.rect.intersection(cases[$1].rect) / region.rect.area
                return abs(a - b) < 0.05 ? cases[$0].rect.area < cases[$1].rect.area : a > b
            }.first
            if let owner { groups[owner].append(region) }
            else { groups.append([region]); blocks.append(region.rect) }
        }
        func indices(_ rects: [UnitRect]) -> [Int] {
            // Confidence carries the index through the existing deterministic XY-cut.
            PanelLayout.ordered(rects.enumerated().map {
                Detection(rect: $0.element, confidence: Double($0.offset), kind: 0)
            }, rtl: rtl).map { Int($0.confidence) }
        }
        return indices(blocks).flatMap { group in
            indices(groups[group].map(\.rect)).map { groups[group][$0] }
        }
    }

    /// Aim for 60% occupancy, while tiny balloons never exceed 3× page scale.
    static func textTransform(for region: PageTextRegion, size: CGSize, visible: CGRect) -> Transform {
        let target = ReadingPanel(id: region.id, rect: region.zoomRect, confidence: region.confidence)
        let inset = visible.insetBy(dx: visible.width * 0.2, dy: visible.height * 0.2)
        return transform(for: target, size: size, visible: inset, maximumScale: 3)
    }

    static func transform(for panel: ReadingPanel, size: CGSize, visible: CGRect, maximumScale: CGFloat = 4) -> Transform {
        let rect = panel.rect.cgRect
        guard size.width > 0, size.height > 0, rect.width > 0, rect.height > 0 else {
            return Transform(scale: 1, x: 0, y: 0)
        }
        // Fit the case into the currently visible slice of this page. Preserve
        // aspect ratio and cap magnification; the page's layout frame never changes.
        let scale = max(1, min(maximumScale, min(visible.width / (rect.width * size.width),
                                    visible.height / (rect.height * size.height))))
        return Transform(scale: scale,
                         x: visible.midX - rect.midX * size.width * scale,
                         y: visible.midY - rect.midY * size.height * scale)
    }
}
