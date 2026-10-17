import Foundation

actor ConversionEngine {
    let detector = LocalPanelDetector()
    let store: DocumentStore
    init(store: DocumentStore) { self.store = store }

    func convert(_ original: MangaDocument,
                 progress: @escaping @Sendable (MangaDocument) async -> Void) async throws -> MangaDocument {
        // A missing/incompatible model is an error, never silently a whole-book fallback.
        try await detector.prepare()
        var doc = original
        if doc.engineVersion != MangaDocument.engine {
            doc.engineVersion = MangaDocument.engine
            for index in doc.pages.indices { doc.pages[index].processed = false }
            try store.save(doc)
        }
        for index in doc.pages.indices where !doc.pages[index].processed {
            try Task.checkCancellation()
            let start = Date()
            let url = store.pageURL(doc, doc.pages[index])
            var page = doc.pages[index]
            page.fallback = false
            page.warning = nil
            do {
                let dimensions = try PageImage.dimensions(at: url)
                page.width = dimensions.0; page.height = dimensions.1
                let image = try autoreleasepool { try PageImage.load(at: url, maxPixel: 1600) }
                let detections = try await detector.detect(image: image)
                page.panels = PanelLayout.readingPanels(detections, pageID: page.id, rtl: doc.rightToLeft)
                page.panels = ContourRefiner.refine(image: image, panels: page.panels, texts: detections)
                if page.panels.isEmpty {
                    page.fallback = true
                    page.panels = [ReadingPanel(id: "\(page.id)-full", rect: .full, confidence: 0)]
                }
            } catch let error as MangaError {
                if case .invalidImage = error {
                    page.warning = error.localizedDescription
                    page.fallback = true
                    page.panels = [ReadingPanel(id: "\(page.id)-full", rect: .full, confidence: 0)]
                    page.width = 1000; page.height = 1400
                } else { throw error }
            }
            try Task.checkCancellation()
            page.processed = true
            page.milliseconds = Date().timeIntervalSince(start) * 1000
            doc.pages[index] = page
            try store.save(doc)
            await progress(doc)
        }
        return doc
    }
}
