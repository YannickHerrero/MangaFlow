import SwiftUI

struct ReaderView: View {
    let document: MangaDocument
    let store: DocumentStore
    var onPosition: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var position: String?
    @State private var original: MangaPage?
    @State private var leftToRight = false
    @State private var restored = false
    private struct Row: Identifiable {
        let page: MangaPage
        let panel: ReadingPanel
        var id: String { panel.id }
    }
    private var rows: [Row] {
        document.pages.filter(\.processed).flatMap { page in
            let panels: [ReadingPanel]
            if leftToRight {
                let boxes = page.panels.map { Detection(rect: $0.rect, confidence: $0.confidence, kind: 0) }
                panels = PanelLayout.ordered(boxes, rtl: false).compactMap { box in page.panels.first { $0.rect == box.rect } }
            } else { panels = page.panels }
            return panels.map { Row(page: page, panel: $0) }
        }
    }
    private var currentPage: Int {
        rows.first(where: { $0.id == position })?.page.id ?? 0
    }
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 22) {
                        ForEach(rows) { row in
                            VStack(spacing: 8) {
                                if row.panel.id == row.page.panels.first?.id {
                                    HStack {
                                        Text("PAGE \(row.page.id + 1)").tracking(2)
                                        Spacer()
                                        if row.page.fallback { Text("PAGE ENTIÈRE") }
                                    }.font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.gray).padding(.horizontal, 16)
                                }
                                let ratio = max(0.1, Double(max(row.page.width, 1)) * row.panel.rect.width / (Double(max(row.page.height, 1)) * row.panel.rect.height))
                                CropImage(url: store.pageURL(document, row.page), rect: row.panel.rect,
                                          targetWidth: min(1600, Int(geometry.size.width * 3)))
                                    .frame(width: geometry.size.width, height: geometry.size.width / ratio)
                                    .background(.white)
                                    .contentShape(Rectangle())
                                    .onTapGesture { original = row.page }
                                    .accessibilityLabel("Page \(row.page.id + 1), case \(row.panel.id). Toucher pour voir la page originale.")
                            }.id(row.id)
                        }
                        Label("Fin du chapitre", systemImage: "checkmark.circle")
                            .font(.subheadline).foregroundStyle(FlowStyle.accent).padding(40)
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 18)
                }
                .scrollPosition(id: $position, anchor: .top)
                .background(Color.black)
                .onChange(of: position) { _, value in
                    if restored, let value { onPosition(value) }
                }
                .task {
                    guard !restored else { return }
                    position = document.lastPanelID ?? rows.first?.id
                    restored = true
                }
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(FlowStyle.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.down") }.accessibilityLabel("Fermer la lecture")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Voir la page originale") { original = document.pages.first { $0.id == currentPage } }
                        Toggle("Lecture de gauche à droite", isOn: $leftToRight)
                        Button("Revenir au début") { position = rows.first?.id }
                    } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Options de lecture")
                }
                ToolbarItem(placement: .bottomBar) {
                    Text("\(min(currentPage + 1, document.pages.count)) / \(document.pages.count) · Toucher une case pour voir la page")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
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
}

struct OriginalPageView: View {
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
