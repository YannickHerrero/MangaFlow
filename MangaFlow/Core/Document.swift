import Foundation
import CoreGraphics

struct UnitRect: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    static let full = UnitRect(x: 0, y: 0, width: 1, height: 1)
    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
    var area: Double { max(0, width) * max(0, height) }
    var maxX: Double { x + width }
    var maxY: Double { y + height }
    var midX: Double { x + width / 2 }
    var midY: Double { y + height / 2 }
    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    init(_ rect: CGRect) {
        x = rect.minX; y = rect.minY; width = rect.width; height = rect.height
    }
    func clamped() -> UnitRect { UnitRect(cgRect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))) }
    func intersection(_ other: UnitRect) -> Double {
        let rect = cgRect.intersection(other.cgRect)
        return rect.isNull ? 0 : rect.width * rect.height
    }
    func padded(_ margin: Double) -> UnitRect {
        UnitRect(cgRect.insetBy(dx: -margin, dy: -margin)).clamped()
    }
}

struct Detection: Sendable {
    var rect: UnitRect
    var confidence: Double
    var kind: Int // 0 panel, 1 text
}

struct ReadingPanel: Codable, Identifiable, Sendable {
    var id: String
    var rect: UnitRect
    var confidence: Double
    var contour: PanelContour? = nil
}

struct PagePoint: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
}

struct PanelContour: Codable, Equatable, Sendable {
    /// Full-page coordinates, origin at top left. The image is masked, never warped.
    var points: [PagePoint]
    var protectedRects: [UnitRect] = []
}

struct MangaPage: Codable, Identifiable, Sendable {
    var id: Int
    var filename: String
    var width: Int = 0
    var height: Int = 0
    var panels: [ReadingPanel] = []
    var processed = false
    var fallback = false
    var warning: String?
    var milliseconds: Double = 0
}

struct MangaDocument: Codable, Identifiable, Sendable {
    static let engine = "yolo26-fp32-contours-v2"
    var schema = 1
    var engineVersion = Self.engine
    var id: UUID
    var title: String
    var created = Date()
    var rightToLeft = true
    var pages: [MangaPage]
    var lastPanelID: String?
    var complete: Bool { pages.allSatisfy(\.processed) }
    var panelCount: Int { pages.reduce(0) { $0 + $1.panels.count } }
    var processedCount: Int { pages.filter(\.processed).count }
    var fallbackCount: Int { pages.filter(\.fallback).count }
}

enum MangaError: LocalizedError {
    case invalidArchive(String), invalidImage, missingModel, invalidModel(String)
    var errorDescription: String? {
        switch self {
        case .invalidArchive(let message): return message
        case .invalidImage: return "Cette image est illisible ou trop grande."
        case .missingModel: return "Le modèle de détection manque dans cette version de l’app."
        case .invalidModel(let message): return "Sortie du détecteur incompatible : \(message)"
        }
    }
}
