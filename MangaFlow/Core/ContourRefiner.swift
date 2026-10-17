import Foundation
import CoreGraphics

/// Conservative straight-border fitting around existing detections. No model or network dependency.
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
            guard let border = fit(in: page, rect: rect, horizontal: horizontal, inward: inward) else { continue }
            let clipped = clip(polygon, border: border, width: page.width, height: page.height)
            let retained = area(clipped) / rect.area
            // Reject aggressive cuts and crossings; uncertain edges leave the rectangle untouched.
            guard clipped.count >= 3, retained >= 0.60 else { continue }
            polygon = clipped
            accepted += 1
        }
        guard accepted > 0, area(polygon) < rect.area * 0.985 else { return nil }
        return PanelContour(points: polygon, protectedRects: protectedRects.map { UnitRect($0.cgRect.intersection(rect.cgRect)) }.filter { $0.area > 0 })
    }

    static func fit(in page: GrayPage, rect: UnitRect, horizontal: Bool, inward: Double) -> Border? {
        let w = Double(page.width), h = Double(page.height)
        let start = horizontal ? rect.x * w : rect.y * h
        let length = horizontal ? rect.width * w : rect.height * h
        let depth = horizontal ? rect.height * h : rect.width * w
        let target = horizontal ? (inward > 0 ? rect.y : rect.maxY) * h : (inward > 0 ? rect.x : rect.maxX) * w
        let limit = horizontal ? h : w
        guard length > 45, depth > 25, target > 2, target < limit - 2 else { return nil }
        let reach = min(70, min(depth * 0.40, length * 0.22))
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
        let slopeLimit = min(0.28, 2 * reach / length)
        for step in -14...14 {
            let slope = Double(step) * slopeLimit / 14
            for offset in stride(from: -reach, through: reach, by: 2.0) {
                let mid = target + offset
                let measured = score(slope, mid)
                // Prefer the closest border when image content yields similarly strong candidates.
                let value = measured.0 - abs(offset) / max(reach, 1) * 0.035
                if best == nil || value > best!.score { best = (value, measured.1, slope, mid) }
            }
        }
        guard var best else { return nil }
        let coarseSlope = best.slope, coarseMid = best.mid
        for slopeStep in -3...3 {
            let slope = coarseSlope + Double(slopeStep) * slopeLimit / 56
            for offset in stride(from: -2.0, through: 2.0, by: 0.5) {
                let mid = coarseMid + offset
                let measured = score(slope, mid)
                let value = measured.0 - abs(mid - target) / max(reach, 1) * 0.035
                if value > best.score { best = (value, measured.1, slope, mid) }
            }
        }
        guard best.support >= 0.72, best.score >= 0.73, abs(best.slope) * length >= 5 else { return nil }
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
