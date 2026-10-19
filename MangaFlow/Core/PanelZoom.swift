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
