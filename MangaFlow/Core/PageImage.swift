import UIKit
import ImageIO

enum PageImage {
    static func dimensions(at url: URL) throws -> (Int, Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 30000, height <= 30000,
              Int64(width) * Int64(height) <= 120_000_000 else { throw MangaError.invalidImage }
        let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
        return (5...8).contains(orientation) ? (height, width) : (width, height)
    }
    static func load(at url: URL, maxPixel: Int) throws -> CGImage {
        _ = try dimensions(at: url)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw MangaError.invalidImage }
        return image
    }
    static func crop(at url: URL, rect: UnitRect, contour: PanelContour? = nil, targetWidth: Int) throws -> UIImage {
        // Bound decoding even for tiny panels in enormous scans.
        let (w, h) = try dimensions(at: url)
        let maxPixel = min(6000, max(1200, Int(Double(targetWidth) / max(rect.width, 0.05) * Double(max(w, h)) / Double(w))))
        let image = try load(at: url, maxPixel: maxPixel)
        let box = CGRect(x: rect.x * Double(image.width), y: rect.y * Double(image.height),
                         width: rect.width * Double(image.width), height: rect.height * Double(image.height))
            .integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let cropped = image.cropping(to: box) else { throw MangaError.invalidImage }
        return masked(cropped, sourceWidth: image.width, sourceHeight: image.height, cropBox: box, contour: contour)
    }
    static func masked(_ cropped: CGImage, sourceWidth: Int, sourceHeight: Int, cropBox: CGRect, contour: PanelContour?) -> UIImage {
        guard let contour, contour.points.count >= 3,
              contour.points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return UIImage(cgImage: cropped) }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
        format.preferredRange = .standard
        let size = CGSize(width: cropped.width, height: cropped.height)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let path = UIBezierPath()
            for (i, p) in contour.points.enumerated() {
                let point = CGPoint(x: p.x * Double(sourceWidth) - cropBox.minX,
                                    y: p.y * Double(sourceHeight) - cropBox.minY)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.close()
            for r in contour.protectedRects {
                path.append(UIBezierPath(rect: CGRect(x: r.x * Double(sourceWidth) - cropBox.minX,
                                                     y: r.y * Double(sourceHeight) - cropBox.minY,
                                                     width: r.width * Double(sourceWidth), height: r.height * Double(sourceHeight))))
            }
            path.addClip()
            UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

actor CropLoader {
    static let shared = CropLoader()
    private let cache = NSCache<NSString, UIImage>()
    init() { cache.totalCostLimit = 48 * 1024 * 1024 }
    func image(url: URL, rect: UnitRect, contour: PanelContour? = nil, width: Int) throws -> UIImage {
        let key = "\(url.path)|\(rect.x),\(rect.y),\(rect.width),\(rect.height)|\(String(describing: contour))|\(width)" as NSString
        if let image = cache.object(forKey: key) { return image }
        let image = try autoreleasepool { try PageImage.crop(at: url, rect: rect, contour: contour, targetWidth: width) }
        let cost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
        cache.setObject(image, forKey: key, cost: cost)
        return image
    }
    func clear() { cache.removeAllObjects() }
}
