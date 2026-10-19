import Foundation

actor ConversionEngine {
    let detector = LocalPanelDetector()
    let textDetector = LocalTextDetector()
    let store: DocumentStore
    init(store: DocumentStore) { self.store = store }

    func convert(_ original: MangaDocument,
                 progress: @escaping @Sendable (MangaDocument) async -> Void) async throws -> MangaDocument {
        // A missing/incompatible model is an error, never silently a whole-book fallback.
        try await detector.prepare()
        try await textDetector.prepare()
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
            page.zoomPanels = nil
            page.textRegions = nil
            do {
                let dimensions = try PageImage.dimensions(at: url)
                page.width = dimensions.0; page.height = dimensions.1
                let image = try autoreleasepool { try PageImage.load(at: url, maxPixel: 1600) }
                let detections = try await detector.detect(image: image)
                let textDetections = try await textDetector.detect(image: image)
                let primaryText = TextRegions.regions(textDetections, fallback: detections, pageID: page.id)
                let narration: [Detection]
                do {
                    narration = try NarrationDetector.detect(image: image, excluding: primaryText.map(\.rect))
                } catch {
                    // Supplementary OCR must never prevent reading or discard primary detections.
                    narration = []
                    page.warning = "Détection complémentaire du texte indisponible ; le zoom sur les cases reste disponible."
                }
                page.textRegions = TextRegions.regions(textDetections, fallback: detections + narration, pageID: page.id)
                let individual = PanelLayout.ordered(PanelLayout.normalized(detections), rtl: doc.rightToLeft)
                    .enumerated().map { index, detection in
                        ReadingPanel(id: "\(page.id)-zoom-\(index)", rect: detection.rect, confidence: detection.confidence)
                    }
                page.zoomPanels = ContourRefiner.refine(image: image, panels: individual, texts: detections)
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
