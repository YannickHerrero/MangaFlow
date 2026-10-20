import SwiftUI

struct ReaderView: View {
    @Environment(\.palette) private var p
    let document: MangaDocument
    let store: DocumentStore
    var onPosition: (String) -> Void
    var onComplete: (() -> Void)? = nil
    var nextChapter: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var position: String?
    @State private var original: MangaPage?
    @AppStorage("leftToRightReading") private var leftToRight = false
    @AppStorage("followPanelBorders") private var followPanelBorders = true
    @AppStorage("readOriginalPages") private var originalPages = false
    @AppStorage("readerTwoFingerHintSeen") private var twoFingerHintSeen = false
    @State private var showGestureHint = false
    @State private var controlsVisible = true
    @State private var restored = false
    private struct Row: Identifiable {
        let page: MangaPage
        let panel: ReadingPanel
        var id: String { panel.id }
    }
    private var rows: [Row] {
        document.pages.filter(\.processed).flatMap { page in
            let panels: [ReadingPanel]
            if originalPages {
                // Keep a canonical panel ID so progress survives mode switches.
                panels = [ReadingPanel(id: page.panels.first?.id ?? "\(page.id)-full", rect: .full, confidence: 1)]
            } else if leftToRight {
                let boxes = page.panels.map { Detection(rect: $0.rect, confidence: $0.confidence, kind: 0) }
                panels = PanelLayout.ordered(boxes, rtl: false).compactMap { box in page.panels.first { $0.rect == box.rect } }
            } else { panels = page.panels }
            return panels.map { Row(page: page, panel: $0) }
        }
    }
    private var currentPage: Int {
        rows.first(where: { $0.id == position })?.page.id ?? 0
    }
    private var currentPanelNumber: Int {
        guard let row = rows.first(where: { $0.id == position }) else { return 1 }
        return (row.page.panels.firstIndex(where: { $0.id == row.id }) ?? 0) + 1
    }
    var body: some View {
        NavigationStack {
          VStack(spacing: 0) {
            if controlsVisible { readerHeader }
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            let ratio = max(0.1, Double(max(row.page.width, 1)) * row.panel.rect.width / (Double(max(row.page.height, 1)) * row.panel.rect.height))
                            if originalPages {
                                OriginalPanelZoomView(page: row.page, url: store.pageURL(document, row.page),
                                                      rightToLeft: document.rightToLeft && !leftToRight, viewportHeight: geometry.size.height, toggleControls: toggleControls)
                                    .frame(width: geometry.size.width, height: geometry.size.width / ratio)
                                    .background(Color.white)
                                    .id(row.id)
                            } else {
                            CropImage(url: store.pageURL(document, row.page), rect: row.panel.rect,
                                      contour: followPanelBorders ? row.panel.contour : nil,
                                      targetWidth: min(1600, Int(geometry.size.width * 3)))
                                .frame(width: geometry.size.width, height: geometry.size.width / ratio)
                                .background(followPanelBorders && row.panel.contour != nil ? Color.clear : Color.white)
                                .contentShape(Rectangle())
                                .readerTaps(onTap: { _ in original = row.page }, onControls: toggleControls)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Page \(row.page.id + 1), case \(row.panel.id). Toucher pour voir la page originale.")
                                .accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier("panel-\(row.panel.id)")
                                .accessibilityAction { original = row.page }
                                .accessibilityAction(named: controlsVisible ? "Masquer les commandes" : "Afficher les commandes") { toggleControls() }
                                .id(row.id)
                            }
                        }
                        if let nextChapter { Button("Chapitre suivant", action: nextChapter).buttonStyle(ThemeButtonStyle()).padding(24).accessibilityIdentifier("nextChapter") }
                    }
                    .scrollTargetLayout()
                }
                .coordinateSpace(name: "readerViewport")
                .scrollPosition(id: $position, anchor: .top)
                .id(originalPages)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height > 0 && geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 24
                } action: { _, atEnd in if atEnd { onComplete?() } }
                .accessibilityIdentifier("readerScroll")
                .accessibilityLabel("Lecture du manga")
                .accessibilityValue("Page \(currentPage + 1), case \(currentPanelNumber)")
                .background(Color.black)
                .onChange(of: position) { _, value in
                    if restored, let value { onPosition(value) }
                }
                .task {
                    guard !restored else { return }
                    if let saved = document.lastPanelID, rows.contains(where: { $0.id == saved }) { position = saved }
                    else if let page = document.lastPanelID?.split(separator: "-").first { position = rows.first { String($0.page.id) == page }?.id ?? rows.first?.id }
                    else { position = rows.first?.id }
                    restored = true
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
          }
            .toolbar(.hidden, for: .navigationBar)
            .statusBarHidden(!controlsVisible)
            .persistentSystemOverlays(controlsVisible ? .automatic : .hidden)
            .sheet(item: $original) { page in
                NavigationStack {
                    OriginalPageView(url: store.pageURL(document, page))
                        .ignoresSafeArea(edges: .bottom)
                        .navigationTitle("Page \(page.id + 1)")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { original = nil } } }
                }.preferredColorScheme(.dark)
            }
        }
        .overlay(alignment: .bottom) {
            if showGestureHint {
                Text("Touchez avec deux doigts pour afficher ou masquer l’interface.")
                    .font(.caption).multilineTextAlignment(.center)
                    .foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.black.opacity(0.85), in: Capsule())
                    .padding(.horizontal, 24).padding(.bottom, 24)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("readerGestureHint")
            }
        }
        .task {
            guard !twoFingerHintSeen else { return }
            twoFingerHintSeen = true
            showGestureHint = true
            try? await Task.sleep(for: .seconds(5))
            showGestureHint = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            Task { await CropLoader.shared.clear() }
        }
    }
    private var readerHeader: some View {
        HStack(spacing: 8) {
            RoundIconButton(symbol: "chevron.down", label: "Fermer la lecture") { dismiss() }
            Text(document.title).font(p.font(16, title: true)).lineLimit(1)
            Spacer(minLength: 0)
            RoundIconButton(symbol: originalPages ? "doc.richtext.fill" : "doc.richtext", label: "Pages originales") { setOriginalPages(!originalPages) }
                .foregroundStyle(originalPages ? p.accent : p.ink)
                .accessibilityValue(originalPages ? "Activé" : "Désactivé").accessibilityIdentifier("readerOriginalPages")
            RoundIconButton(symbol: "eye.slash", label: "Masquer l’interface", action: toggleControls)
                .accessibilityHint("Touchez avec deux doigts pour réafficher les commandes.")
            Menu {
                Button("Voir la page originale") { original = document.pages.first { $0.id == currentPage } }
                Toggle("Lecture de gauche à droite", isOn: $leftToRight)
                Toggle("Suivre les bords des cases", isOn: $followPanelBorders)
                Button("Plein écran · deux doigts pour revenir") { toggleControls() }
                Button("Revenir au début") { position = rows.first?.id }
            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).background(p.surface, in: Circle()).overlay(Circle().stroke(p.line, lineWidth: 1)) }
                .accessibilityLabel("Options de lecture")
        }.padding(.horizontal, 12).padding(.vertical, 8).background(p.paper)
    }
    private func setOriginalPages(_ enabled: Bool) {
        let page = currentPage
        originalPages = enabled
        position = rows.first { $0.page.id == page }?.id ?? rows.first?.id
    }
    private func toggleControls() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { controlsVisible.toggle() }
    }
}

struct OriginalPageView: View {
    @Environment(\.palette) private var p
    let url: URL
    @State private var image: UIImage?
    @State private var failed = false
    var body: some View {
        Group {
            if let image { ZoomablePage(image: image) }
            else if failed { ContentUnavailableView("Image illisible", systemImage: "photo.badge.exclamationmark") }
            else { ProgressView() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(.black)
        .task {
            do { image = try await CropLoader.shared.image(url: url, rect: .full, width: 2200) }
            catch { failed = true }
        }
    }
}

struct ZoomablePage: UIViewRepresentable {
    let image: UIImage
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.backgroundColor = .black
        scroll.minimumZoomScale = 1; scroll.maximumZoomScale = 6
        scroll.delegate = context.coordinator
        let view = context.coordinator.imageView
        view.contentMode = .scaleAspectFit
        scroll.addSubview(view)
        return scroll
    }
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        let view = context.coordinator.imageView
        view.image = image
        view.frame = scroll.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroll.contentSize = scroll.bounds.size
    }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        let imageView = UIImageView()
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    }
}
