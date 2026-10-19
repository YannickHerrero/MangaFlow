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
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            let ratio = max(0.1, Double(max(row.page.width, 1)) * row.panel.rect.width / (Double(max(row.page.height, 1)) * row.panel.rect.height))
                            if originalPages {
                                OriginalPanelZoomView(page: row.page, url: store.pageURL(document, row.page),
                                                      viewportHeight: geometry.size.height, toggleControls: toggleControls)
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
                                .gesture(TapGesture(count: 2).exclusively(before: TapGesture())
                                    .onEnded { gesture in
                                        switch gesture {
                                        case .first: toggleControls()
                                        case .second: original = row.page
                                        }
                                    })
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
            .ignoresSafeArea(.container, edges: originalPages && controlsVisible ? .bottom : .vertical)
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(p.paper, for: .navigationBar)
            .toolbar(controlsVisible ? .visible : .hidden, for: .navigationBar)
            .statusBarHidden(!controlsVisible)
            .persistentSystemOverlays(controlsVisible ? .automatic : .hidden)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.down") }.accessibilityLabel("Fermer la lecture")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: Binding(get: { originalPages }, set: setOriginalPages)) {
                        Image(systemName: "doc.richtext")
                    }.toggleStyle(.button)
                        .accessibilityLabel("Pages originales")
                        .accessibilityHint("Afficher les pages entières en défilement continu, sans recadrage.")
                        .accessibilityIdentifier("readerOriginalPages")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { toggleControls() } label: { Image(systemName: "eye.slash") }
                        .accessibilityLabel("Masquer l’interface")
                        .accessibilityHint("Touchez deux fois une case pour réafficher les commandes.")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Voir la page originale") { original = document.pages.first { $0.id == currentPage } }
                        Toggle("Lecture de gauche à droite", isOn: $leftToRight)
                        Toggle("Suivre les bords des cases", isOn: $followPanelBorders)
                        Button("Plein écran · double toucher pour revenir") { toggleControls() }
                        Button("Revenir au début") { position = rows.first?.id }
                    } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Options de lecture")
                }
            }
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            Task { await CropLoader.shared.clear() }
        }
    }
    private func setOriginalPages(_ enabled: Bool) {
        let page = currentPage
        originalPages = enabled
        position = rows.first { $0.page.id == page }?.id ?? rows.first?.id
    }
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) { controlsVisible.toggle() }
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
