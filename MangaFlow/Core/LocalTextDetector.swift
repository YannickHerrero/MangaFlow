import CoreML
import UIKit

/// Dedicated balloon/free-text model. Runs once at conversion, never on a reader tap.
actor LocalTextDetector {
    private var loaded: MLModel?
    private func model() throws -> MLModel {
        if let loaded { return loaded }
        guard let url = Bundle.main.url(forResource: "TextDetector", withExtension: "mlmodelc") else {
            throw MangaError.invalidModel("modèle de bulles absent")
        }
        let config = MLModelConfiguration()
        #if targetEnvironment(simulator)
        config.computeUnits = .cpuOnly
        #else
        config.computeUnits = .all
        #endif
        let result = try MLModel(contentsOf: url, configuration: config)
        loaded = result
        return result
    }
    func prepare() throws { _ = try model() }

    static func unletterbox(_ rect: CGRect, width: Double, height: Double) -> UnitRect {
        let scale = min(1024 / width, 1024 / height)
        let x = floor((1024 - (width * scale).rounded()) / 2)
        let y = floor((1024 - (height * scale).rounded()) / 2)
        return UnitRect(x: (rect.minX - x) / scale / width, y: (rect.minY - y) / scale / height,
                        width: rect.width / scale / width, height: rect.height / scale / height).clamped()
    }

    func detect(image: CGImage) throws -> [TextDetection] {
        try autoreleasepool {
            let model = try model()
            let w = Double(image.width), h = Double(image.height), scale = min(1024 / w, 1024 / h)
            let sw = (w * scale).rounded(), sh = (h * scale).rounded()
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            let rendered = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024), format: format).image { context in
                UIColor(white: 114.0 / 255, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
                UIImage(cgImage: image).draw(in: CGRect(x: floor((1024 - sw) / 2), y: floor((1024 - sh) / 2), width: sw, height: sh))
            }
            guard let canvas = rendered.cgImage,
                  let constraint = model.modelDescription.inputDescriptionsByName["image"]?.imageConstraint else {
                throw MangaError.invalidModel("entrée du modèle de bulles incompatible")
            }
            let input = try MLFeatureValue(cgImage: canvas, constraint: constraint, options: [:])
            let output = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["image": input]))
            guard let array = output.featureNames.compactMap({ output.featureValue(for: $0)?.multiArrayValue }).first else {
                throw MangaError.invalidModel("sortie du modèle de bulles absente")
            }
            return try Self.decode(array, width: w, height: h)
        }
    }

    static func decode(_ array: MLMultiArray, width: Double, height: Double) throws -> [TextDetection] {
        guard array.shape.map(\.intValue) == [1, 6, 21504] else {
            throw MangaError.invalidModel("format bulles attendu [1, 6, 21504]")
        }
        var candidates: [TextDetection] = []
        for index in 0..<21504 {
            func value(_ channel: Int) -> Double { array[[0, NSNumber(value: channel), NSNumber(value: index)]].doubleValue }
            let bubble = value(4), free = value(5)
            guard bubble.isFinite, free.isFinite else { continue }
            let kind: PageTextKind = bubble >= free ? .bubble : .freeText
            let score = max(bubble, free)
            guard score >= (kind == .bubble ? 0.4 : 0.3) else { continue }
            let coordinates = (0..<4).map(value)
            guard coordinates.allSatisfy(\.isFinite), coordinates[2] > 0, coordinates[3] > 0 else { continue }
            let rect = unletterbox(CGRect(x: coordinates[0] - coordinates[2] / 2,
                                         y: coordinates[1] - coordinates[3] / 2,
                                         width: coordinates[2], height: coordinates[3]), width: width, height: height)
            if rect.area > 0.0001 && rect.area < 0.5 {
                candidates.append(TextDetection(rect: rect, confidence: score, kind: kind))
            }
        }
        return TextRegions.suppressed(candidates)
    }
}
