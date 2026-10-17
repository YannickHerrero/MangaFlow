import CoreML
import UIKit

actor LocalPanelDetector {
    private var loadedModel: MLModel?
    private func model() throws -> MLModel {
        if let loadedModel { return loadedModel }
        guard let url = Bundle.main.url(forResource: "PanelDetector", withExtension: "mlmodelc") else {
            throw MangaError.missingModel
        }
        let config = MLModelConfiguration()
        #if targetEnvironment(simulator)
        config.computeUnits = .cpuOnly
        #else
        config.computeUnits = .all
        #endif
        let model = try MLModel(contentsOf: url, configuration: config)
        loadedModel = model
        return model
    }
    func prepare() throws { _ = try model() }

    static func unletterbox(x1: Double, y1: Double, x2: Double, y2: Double,
                            width: Double, height: Double) -> UnitRect {
        let scale = min(640 / width, 640 / height)
        let padX = (640 - (width * scale).rounded()) / 2
        let padY = (640 - (height * scale).rounded()) / 2
        // Same integer placement as the rendered canvas (odd padding goes to right/bottom).
        return UnitRect(x: (x1 - floor(padX)) / scale / width,
                        y: (y1 - floor(padY)) / scale / height,
                        width: (x2 - x1) / scale / width,
                        height: (y2 - y1) / scale / height).clamped()
    }

    func detect(image: CGImage) throws -> [Detection] {
        try autoreleasepool { try detectPage(image: image) }
    }

    private func detectPage(image: CGImage) throws -> [Detection] {
        let model = try model()
        let width = Double(image.width), height = Double(image.height)
        let scale = min(640 / width, 640 / height)
        let scaledW = (width * scale).rounded(), scaledH = (height * scale).rounded()
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 640), format: format).image { context in
            UIColor(white: 114.0 / 255.0, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 640))
            UIImage(cgImage: image).draw(in: CGRect(x: floor((640 - scaledW) / 2), y: floor((640 - scaledH) / 2), width: scaledW, height: scaledH))
        }
        guard let canvas = rendered.cgImage,
              let constraint = model.modelDescription.inputDescriptionsByName["image"]?.imageConstraint else {
            throw MangaError.invalidModel("entrée image absente")
        }
        let input = try MLFeatureValue(cgImage: canvas, constraint: constraint, options: [:])
        let output = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["image": input]))
        guard let array = output.featureNames.compactMap({ output.featureValue(for: $0)?.multiArrayValue }).first,
              array.shape.map(\.intValue) == [1, 300, 6] else {
            throw MangaError.invalidModel("format attendu [1, 300, 6]")
        }
        var detections: [Detection] = []
        for row in 0..<300 {
            func value(_ col: Int) -> Double { array[[0, NSNumber(value: row), NSNumber(value: col)]].doubleValue }
            let confidence = value(4)
            guard confidence.isFinite, confidence >= 0.25 else { continue }
            let coordinates = (0..<4).map(value)
            guard coordinates.allSatisfy(\.isFinite), coordinates[2] > coordinates[0], coordinates[3] > coordinates[1], value(5).isFinite else { continue }
            let rect = Self.unletterbox(x1: coordinates[0], y1: coordinates[1], x2: coordinates[2], y2: coordinates[3], width: width, height: height)
            if rect.area > 0 { detections.append(Detection(rect: rect, confidence: confidence, kind: Int(value(5).rounded()))) }
        }
        return detections
    }
}
