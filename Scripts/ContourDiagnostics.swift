import Foundation
import ImageIO

@main
struct ContourDiagnostics {
    static func main() throws {
        let args = CommandLine.arguments
        var document = try JSONDecoder().decode(MangaDocument.self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
        let directory = URL(fileURLWithPath: args[2])
        for i in document.pages.indices {
            let page = document.pages[i]
            let imageURL = directory.appendingPathComponent(page.filename)
            guard !page.fallback,
                  let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1600,
                    kCGImageSourceCreateThumbnailWithTransform: true
                  ] as CFDictionary) else { continue }
            let start = Date()
            document.pages[i].panels = ContourRefiner.refine(image: image, panels: page.panels, texts: [])
            let refined = document.pages[i].panels.filter { $0.contour != nil }
            print("Page \(i+1): \(refined.count)/\(page.panels.count) contours, \(Int(Date().timeIntervalSince(start)*1000)) ms")
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        try encoder.encode(document).write(to: URL(fileURLWithPath: args[3]))
    }
}
