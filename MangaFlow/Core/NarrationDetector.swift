import Vision
import CoreML

/// Supplement stylized free text missed by either object detector. Recognized strings
/// are only used to reject noise; they are never saved, displayed, logged or sent out.
enum NarrationDetector {
    static func detect(image: CGImage, excluding known: [UnitRect]) throws -> [Detection] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = true
        request.minimumTextHeight = 0.012
        // CPU avoids expensive first-use ANE compilation for this supplementary pass.
        for (stage, devices) in try request.supportedComputeStageDevices {
            if let cpu = devices.first(where: { if case .cpu = $0 { return true }; return false }) {
                request.setComputeDevice(cpu, for: stage)
            }
        }
        try VNImageRequestHandler(cgImage: image).perform([request])
        let lines: [Detection] = (request.results ?? []).compactMap { item in
            guard let text = item.topCandidates(1).first, text.confidence >= 0.5,
                  text.string.filter({ $0.isLetter || $0.isNumber }).count >= 2 else { return nil }
            let r = item.boundingBox
            let rect = UnitRect(x: r.minX, y: 1 - r.maxY, width: r.width, height: r.height).clamped()
            // Strongly rotated clothing lettering often looks like dialogue to OCR.
            guard abs(item.topRight.y - item.topLeft.y) < max(0.005, abs(item.topRight.x - item.topLeft.x) * 0.3),
                  rect.area > 0.0002, rect.area < 0.22,
                  !known.contains(where: { rect.intersection($0) / rect.area > 0.6 }) else { return nil }
            return Detection(rect: rect, confidence: Double(text.confidence), kind: 1)
        }
        return grouped(lines)
    }

    static func grouped(_ lines: [Detection]) -> [Detection] {
        var groups: [Detection] = []
        for line in lines.sorted(by: { $0.rect.y < $1.rect.y }) {
            if let index = groups.indices.last(where: { index in
                let a = groups[index].rect, b = line.rect
                let overlap = max(0, min(a.maxX, b.maxX) - max(a.x, b.x)) / min(a.width, b.width)
                let gap = b.y - a.maxY
                return gap >= -min(a.height, b.height) * 0.25 && gap < b.height * 0.55 && overlap > 0.45 &&
                    UnitRect(a.cgRect.union(b.cgRect)).area < 0.22
            }) {
                groups[index].rect = UnitRect(groups[index].rect.cgRect.union(line.rect.cgRect))
                groups[index].confidence = min(groups[index].confidence, line.confidence)
            } else { groups.append(line) }
        }
        return groups
    }
}
