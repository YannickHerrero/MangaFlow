import SwiftUI

struct CropImage: View {
    let url: URL?
    let rect: UnitRect
    var contour: PanelContour? = nil
    var targetWidth = 1200
    @State private var image: UIImage?
    @State private var failed = false
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else if failed { Image(systemName: "photo.badge.exclamationmark").foregroundStyle(.secondary) }
            else { ProgressView().tint(.gray).frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .task(id: "\(url?.path ?? "")-\(rect)-\(String(describing: contour))-\(targetWidth)") {
            guard let url else { return }
            image = nil; failed = false
            do {
                let loaded = try await CropLoader.shared.image(url: url, rect: rect, contour: contour, width: targetWidth)
                try Task.checkCancellation()
                image = loaded
            } catch is CancellationError {} catch { failed = true }
        }
        .onDisappear { image = nil }
    }
}
