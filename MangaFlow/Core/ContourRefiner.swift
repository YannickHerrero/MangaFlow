import Foundation
import CoreGraphics

/// Image-supported polygon masks around existing detections. No model or network dependency.
enum ContourRefiner {
    struct GrayPage {
        let width: Int
        let height: Int
        let pixels: [UInt8]
        init?(image: CGImage) {
            let scale = min(1, 1000 / Double(max(image.width, image.height)))
            let width = max(1, Int((Double(image.width) * scale).rounded()))
            let height = max(1, Int((Double(image.height) * scale).rounded()))
            var buffer = [UInt8](repeating: 255, count: width * height)
            let success = buffer.withUnsafeMutableBytes { bytes -> Bool in
                guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                              bitsPerComponent: 8, bytesPerRow: width,
                                              space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
                context.interpolationQuality = .high
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            guard success else { return nil }
            self.width = width; self.height = height
            pixels = buffer
        }
        init(width: Int, height: Int, pixels: [UInt8]) {
            self.width = width; self.height = height; self.pixels = pixels
        }
        func white(_ x: Int, _ y: Int) -> Double {
            guard x >= 0, y >= 0, x < width, y < height else { return 1 }
            return Double(pixels[y * width + x]) / 255
        }
    }
    struct Border {
        let horizontal: Bool
        let inward: Double
        /// dependent = slope * independent + intercept, in analysis pixels.
        let slope: Double
        let intercept: Double
        let support: Double
    }

    static func refine(image: CGImage, panels: [ReadingPanel], texts: [Detection]) -> [ReadingPanel] {
        guard let gray = GrayPage(image: image) else { return panels }
        var protected = [[UnitRect]](repeating: [], count: panels.count)
        for text in texts where text.kind == 1 && text.confidence >= 0.35 && text.rect.area > 0 {
            let matches = panels.enumerated().map { ($0.offset, $0.element.rect.intersection(text.rect) / text.rect.area) }
            if let best = matches.max(by: { $0.1 < $1.1 }), best.1 > 0.25 {
                protected[best.0].append(text.rect.padded(0.005))
            }
        }
        return panels.enumerated().map { index, panel in
            var result = panel
            result.contour = contour(in: gray, rect: panel.rect, protectedRects: protected[index])
            return result
        }
    }

    static func contour(in page: GrayPage, rect: UnitRect, protectedRects: [UnitRect] = []) -> PanelContour? {
        guard rect.area > 0.008, rect.area < 0.94 else { return nil }
        var polygon = [PagePoint(x: rect.x, y: rect.y), PagePoint(x: rect.maxX, y: rect.y),
                       PagePoint(x: rect.maxX, y: rect.maxY), PagePoint(x: rect.x, y: rect.maxY)]
        var accepted = 0
        for (horizontal, inward) in [(true, 1.0), (true, -1.0), (false, 1.0), (false, -1.0)] {
            // After fitting top/bottom, only sample the surviving side edge.
            // Otherwise the neighbour below a triangular corner can dominate it.
            var fittingRect = rect
            if !horizontal {
                let edge = inward > 0 ? rect.x : rect.maxX
                let points = polygon.filter { abs($0.x - edge) < 0.00001 }
                if let first = points.map(\.y).min(), let last = points.map(\.y).max(), last > first {
                    fittingRect = UnitRect(x: rect.x, y: first, width: rect.width, height: last - first)
                }
            }
            var borders: [Border] = []
            if let border = fit(in: page, rect: fittingRect, horizontal: horizontal, inward: inward) {
                borders = [border]
            } else if horizontal, let pair = cornerBorders(in: page, rect: rect, inward: inward) {
                borders = pair
            }
            guard !borders.isEmpty else { continue }
            let clipped = borders.reduce(polygon) { clip($0, border: $1, width: page.width, height: page.height) }
            let retained = area(clipped) / rect.area
            // Reject aggressive cuts and crossings; uncertain edges leave the rectangle untouched.
            guard clipped.count >= 3, retained >= 0.50 else { continue }
            polygon = clipped
            accepted += 1
        }
        guard accepted > 0, area(polygon) < rect.area * 0.985 else { return nil }
        return PanelContour(points: polygon, protectedRects: protectedRects.map { UnitRect($0.cgRect.intersection(rect.cgRect)) }.filter { $0.area > 0 })
    }

    /// Two supported edges can meet at a convex corner (e.g. a triangular panel).
    private static func cornerBorders(in page: GrayPage, rect: UnitRect, inward: Double) -> [Border]? {
        let left = UnitRect(x: rect.x, y: rect.y, width: rect.width * 0.48, height: rect.height)
        let right = UnitRect(x: rect.x + rect.width * 0.52, y: rect.y, width: rect.width * 0.48, height: rect.height)
        guard let a = fit(in: page, rect: left, horizontal: true, inward: inward),
              let b = fit(in: page, rect: right, horizontal: true, inward: inward),
              a.support >= 0.72, b.support >= 0.72,
              (b.slope - a.slope) * inward > 0.15 else { return nil }
        let crossing = (a.intercept - b.intercept) / (b.slope - a.slope) / Double(page.width)
        guard crossing > rect.x + rect.width * 0.20,
              crossing < rect.x + rect.width * 0.80 else { return nil }
        return [a, b]
    }

    static func fit(in page: GrayPage, rect: UnitRect, horizontal: Bool, inward: Double) -> Border? {
        let w = Double(page.width), h = Double(page.height)
        let start = horizontal ? rect.x * w : rect.y * h
        let length = horizontal ? rect.width * w : rect.height * h
        let depth = horizontal ? rect.height * h : rect.width * w
        let target = horizontal ? (inward > 0 ? rect.y : rect.maxY) * h : (inward > 0 ? rect.x : rect.maxX) * w
        let limit = horizontal ? h : w
        guard length > 45, depth > 25, target >= 0, target <= limit else { return nil }
        let reach = min(180, min(depth * 0.60, length * 0.45))
        let center = start + length / 2
        let samples = 64
        let trim = max(3, length * 0.045)
        // Exclude corners: neighbouring borders otherwise overwhelm short side fits.
        let positions = (0..<samples).map { start + trim + (length - 2 * trim) * Double($0) / Double(samples - 1) }
        func brightness(_ a: Double, _ b: Double) -> Double {
            horizontal ? page.white(Int(a.rounded()), Int(b.rounded())) : page.white(Int(b.rounded()), Int(a.rounded()))
        }
        func score(_ slope: Double, _ mid: Double) -> (Double, Double) {
            var hits = 0.0, sum = 0.0
            for a in positions {
                let b = mid + slope * (a - center)
                let ink = 1 - min(brightness(a, b - 0.7), min(brightness(a, b), brightness(a, b + 0.7)))
                let outside = (brightness(a, b - inward * 3) + brightness(a, b - inward * 5)) / 2
                let insideInk = 1 - (brightness(a, b + inward * 5) + brightness(a, b + inward * 9)) / 2
                if ink > 0.65 && outside > 0.72 { hits += 1 }
                sum += ink * outside * (0.7 + 0.3 * insideInk)
            }
            let support = hits / Double(samples)
            return (sum / Double(samples) * 0.6 + support * 0.4, support)
        }
        var best: (score: Double, support: Double, slope: Double, mid: Double)?
        let slopeLimit = min(0.75, 2 * reach / length)
        // Vote from observed ink/white transitions instead of a sparse grid of
        // slopes: a one-pixel gutter edge is easily missed by a coarse grid.
        var edgePoints: [(Double, Double)] = []
        for a in positions {
            var previousHit = false
            for b in stride(from: max(1, target - reach), through: min(limit - 2, target + reach), by: 1.0) {
                let hit = brightness(a, b) < 0.40 &&
                    (brightness(a, b - inward * 3) + brightness(a, b - inward * 5)) / 2 > 0.78
                if hit && !previousHit { edgePoints.append((a, b)) }
                previousHit = hit
            }
        }
        let steps = max(14, Int(ceil(slopeLimit * length / 2)))
        var hypotheses: [(votes: Int, slope: Double, mid: Double)] = []
        for step in -steps...steps {
            let slope = Double(step) * slopeLimit / Double(steps)
            var votes: [Int: Int] = [:]
            for (a, b) in edgePoints {
                let mid = b - slope * (a - center)
                guard abs(mid - target) <= reach else { continue }
                votes[Int((mid / 2).rounded()), default: 0] += 1
            }
            if let bin = votes.max(by: { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }) {
                hypotheses.append((bin.value, slope, Double(bin.key) * 2))
            }
        }
        let ranked = hypotheses.sorted {
            if $0.votes != $1.votes { return $0.votes > $1.votes }
            if abs($0.slope) != abs($1.slope) { return abs($0.slope) < abs($1.slope) }
            return $0.mid < $1.mid
        }
        for candidate in ranked.prefix(32) {
            for offset in stride(from: -1.5, through: 1.5, by: 0.5) {
                let mid = candidate.mid + offset
                let measured = score(candidate.slope, mid)
                let extreme = mid - inward * abs(candidate.slope) * length / 2
                guard abs(extreme - target) <= max(14, depth * 0.18) else { continue }
                let value = measured.0 - abs(extreme - target) / max(depth, 1) * 0.20
                if best == nil || value > best!.score { best = (value, measured.1, candidate.slope, mid) }
            }
        }
        guard var best else { return nil }
        let coarseSlope = best.slope, coarseMid = best.mid
        for slopeStep in -3...3 {
            let slope = coarseSlope + Double(slopeStep) / max(length, 1)
            for offset in stride(from: -2.0, through: 2.0, by: 0.5) {
                let mid = coarseMid + offset
                let measured = score(slope, mid)
                let extreme = mid - inward * abs(slope) * length / 2
                guard abs(extreme - target) <= max(14, depth * 0.18) else { continue }
                let value = measured.0 - abs(extreme - target) / max(depth, 1) * 0.20
                if value > best.score { best = (value, measured.1, slope, mid) }
            }
        }
        guard best.support >= 0.60, best.score >= 0.62, abs(best.slope) * length >= 5 else { return nil }
        // The detected bounding box should enclose this edge. Don't follow a line far inside artwork.
        let edgeExtreme = best.mid - inward * abs(best.slope) * length / 2
        guard abs(edgeExtreme - target) <= max(7, reach * 0.9) else { return nil }
        return Border(horizontal: horizontal, inward: inward, slope: best.slope,
                      intercept: best.mid - best.slope * center, support: best.support)
    }

    static func clip(_ points: [PagePoint], border: Border, width: Int, height: Int) -> [PagePoint] {
        func distance(_ p: PagePoint) -> Double {
            let a = border.horizontal ? p.x * Double(width) : p.y * Double(height)
            let b = border.horizontal ? p.y * Double(height) : p.x * Double(width)
            // Keep the border itself and a small outward margin, including anti-aliased pixels.
            return border.inward * (b - border.slope * a - border.intercept) + 1.5
        }
        var result: [PagePoint] = []
        guard var previous = points.last else { return result }
        var prevDistance = distance(previous)
        for current in points {
            let currentDistance = distance(current)
            if (currentDistance >= 0) != (prevDistance >= 0) {
                let t = prevDistance / (prevDistance - currentDistance)
                result.append(PagePoint(x: previous.x + t * (current.x - previous.x), y: previous.y + t * (current.y - previous.y)))
            }
            if currentDistance >= 0 { result.append(current) }
            previous = current; prevDistance = currentDistance
        }
        return result
    }
    static func area(_ points: [PagePoint]) -> Double {
        guard points.count >= 3 else { return 0 }
        var sum = 0.0
        for i in points.indices {
            let next = points[(i + 1) % points.count]
            sum += points[i].x * next.y - next.x * points[i].y
        }
        return abs(sum) / 2
    }
}
