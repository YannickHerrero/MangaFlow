import SwiftUI

/// Drawing-only zoom: the scroll row keeps its original dimensions and position.
struct OriginalPanelZoomView: View {
    let page: MangaPage
    let url: URL
    let viewportHeight: CGFloat
    let toggleControls: () -> Void
    @State private var focused: String?
    @State private var transform = PanelZoom.Transform(scale: 1, x: 0, y: 0)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var panels: [ReadingPanel] { page.zoomPanels ?? page.panels }
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let frame = geometry.frame(in: .named("readerViewport"))
            let visible = CGRect(x: 0, y: max(0, -frame.minY), width: size.width,
                                 height: max(1, min(size.height, viewportHeight - frame.minY) - max(0, -frame.minY)))
            CropImage(url: url, rect: .full, targetWidth: min(2400, Int(size.width * 4)))
                .frame(width: size.width, height: size.height)
                .scaleEffect(transform.scale, anchor: .topLeading)
                .offset(x: transform.x, y: transform.y)
                .frame(width: size.width, height: size.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(TapGesture(count: 2).exclusively(before: SpatialTapGesture())
                    .onEnded { value in
                        switch value {
                        case .first: toggleControls()
                        case .second(let tap):
                            if focused != nil { reset() }
                            else if let panel = PanelZoom.panel(at: CGPoint(x: tap.location.x / size.width, y: tap.location.y / size.height), in: panels) {
                                zoom(panel, size: size, visible: visible)
                            }
                        }
                    })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page originale \(page.id + 1)")
                .accessibilityValue(focused == nil ? "Page entière" : "Case agrandie")
                .accessibilityHint("Toucher une case pour zoomer, toucher à nouveau pour revenir à la page entière.")
                .accessibilityIdentifier("original-page-\(page.id)")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    if focused != nil { reset() }
                    else if let panel = panels.first(where: { $0.rect.area < 0.94 }) { zoom(panel, size: size, visible: visible) }
                }
                .accessibilityActions {
                    ForEach(Array(panels.filter { $0.rect.area < 0.94 }.enumerated()), id: \.element.id) { index, panel in
                        Button("Agrandir la case \(index + 1)") { zoom(panel, size: size, visible: visible) }
                    }
                    if focused != nil { Button("Revenir à la page entière") { reset() } }
                    Button("Afficher ou masquer les commandes", action: toggleControls)
                }
                .onChange(of: size) { _, _ in reset() }
                .onChange(of: viewportHeight) { _, _ in
                    if let focused, let panel = panels.first(where: { $0.id == focused }) {
                        zoom(panel, size: size, visible: visible)
                    }
                }
        }
        .onDisappear { reset() }
    }
    private func zoom(_ panel: ReadingPanel, size: CGSize, visible: CGRect) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            focused = panel.id
            transform = PanelZoom.transform(for: panel, size: size, visible: visible)
        }
    }
    private func reset() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            focused = nil
            transform = .init(scale: 1, x: 0, y: 0)
        }
    }
}
