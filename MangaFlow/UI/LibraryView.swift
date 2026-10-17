import SwiftUI
import UniformTypeIdentifiers

enum FlowStyle {
    static let background = Color(red: 0.055, green: 0.065, blue: 0.08)
    static let surface = Color(red: 0.10, green: 0.115, blue: 0.13)
    static let accent = Color(red: 0.77, green: 0.96, blue: 0.46)
    static let paper = Color(red: 0.94, green: 0.93, blue: 0.89)
}

struct LibraryView: View {
    @Bindable var library: LibraryModel
    @State private var showImporter = false
    @State private var pendingRemoval: MangaDocument?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.split.3x1.fill").foregroundStyle(FlowStyle.accent)
                        Text("MANGAFLOW").font(.system(size: 14, weight: .heavy, design: .monospaced)).tracking(3)
                        Spacer()
                        Text("SUR TON IPHONE").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Tes mangas.\nUn autre rythme.")
                            .font(.system(size: 43, weight: .bold, design: .rounded)).tracking(-1.7)
                            .foregroundStyle(FlowStyle.paper)
                        Text("Importe un CBZ. Retrouve ses cases dans un fil vertical, prêt à défiler.")
                            .font(.system(size: 16)).foregroundStyle(.secondary).lineSpacing(4)
                    }
                    Button { showImporter = true } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill").font(.title3)
                            Text("Importer un manga").fontWeight(.bold)
                            Spacer()
                            Image(systemName: "arrow.up.doc")
                        }.padding(20).foregroundStyle(.black).background(FlowStyle.accent, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .accessibilityIdentifier("importCBZ")
                    .disabled(library.isBusy)
                    if library.isBusy { conversionCard }
                    HStack {
                        Text("TA LECTURE").font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(2)
                        Spacer()
                        Text("\(library.documents.count) document\(library.documents.count > 1 ? "s" : "")").font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 4)
                    if library.documents.isEmpty && !library.isBusy { emptyState }
                    ForEach(library.documents) { document in
                        documentCard(document)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "iphone.gen3.radiowaves.left.and.right.slash")
                        Text("Conversion locale · Lecture hors ligne")
                    }.font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 8)
                }.padding(24)
            }
            .background(FlowStyle.background)
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType(filenameExtension: "cbz") ?? .zip, .zip], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls): if let url = urls.first { library.importCBZ(url) }
                case .failure(let error): library.error = error.localizedDescription
                }
            }
            .fullScreenCover(item: Binding(get: {
                library.documents.first { $0.id == library.selected }
            }, set: { if $0 == nil { library.selected = nil } })) { document in
                ReaderView(document: document, store: library.store) { panel in
                    library.remember(documentID: document.id, panelID: panel)
                }
            }
            .alert("Impossible de continuer", isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })) {
                Button("Compris", role: .cancel) { library.error = nil }
            } message: { Text(library.error ?? "") }
            .confirmationDialog("Supprimer ce manga et ses fichiers locaux ?", isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }), titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) { if let doc = pendingRemoval { library.remove(doc) }; pendingRemoval = nil }
            }
        }
    }
    private var conversionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { ProgressView().tint(FlowStyle.accent); Text("Préparation de ta lecture").fontWeight(.semibold); Spacer() }
            if let doc = library.activeDocument {
                ProgressView(value: Double(doc.processedCount), total: Double(max(doc.pages.count, 1))).tint(FlowStyle.accent)
            }
            HStack {
                Text(library.status).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Pause") { library.cancel() }.font(.caption.bold()).accessibilityIdentifier("pauseConversion")
            }
            Text("Garde l’app ouverte. Tu peux reprendre après une interruption.").font(.caption2).foregroundStyle(.secondary)
        }.padding(20).background(FlowStyle.surface, in: RoundedRectangle(cornerRadius: 20))
    }
    private var emptyState: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 5) {
                RoundedRectangle(cornerRadius: 4).fill(FlowStyle.paper.opacity(0.8)).frame(width: 50, height: 80)
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 4).fill(FlowStyle.paper.opacity(0.5)).frame(width: 70, height: 37)
                    RoundedRectangle(cornerRadius: 4).fill(FlowStyle.accent.opacity(0.7)).frame(width: 70, height: 38)
                }
                Image(systemName: "arrow.down").font(.title2).foregroundStyle(FlowStyle.accent).padding(.leading, 15).padding(.top, 25)
            }.padding(.top, 8)
            Text("Le prochain chapitre commence ici.").font(.subheadline.weight(.semibold))
            Text("Choisis un fichier .cbz dans Fichiers.\nSes images restent sur ton appareil.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(4)
        }.frame(maxWidth: .infinity).padding(28).background(FlowStyle.surface, in: RoundedRectangle(cornerRadius: 24))
    }
    private func documentCard(_ doc: MangaDocument) -> some View {
        HStack(spacing: 16) {
            CropImage(url: doc.pages.first.map { library.store.pageURL(doc, $0) }, rect: .full, targetWidth: 180)
                .frame(width: 66, height: 92).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 7) {
                Text(doc.title).font(.headline).lineLimit(2)
                Text("\(doc.pages.count) pages · \(doc.panelCount) cases").font(.caption).foregroundStyle(.secondary)
                Button {
                    if doc.complete { library.selected = doc.id } else { library.resume(doc) }
                } label: {
                    Label(doc.complete ? (doc.lastPanelID == nil ? "Lire" : "Continuer") : "Reprendre la conversion", systemImage: doc.complete ? "arrow.down" : "play.fill")
                        .font(.caption.bold())
                }.disabled(library.isBusy).accessibilityIdentifier("read-\(doc.title)")
            }
            Spacer(minLength: 0)
            Menu {
                if doc.processedCount > 0 { Button("Lire les pages prêtes") { library.selected = doc.id } }
                Button("Supprimer", role: .destructive) { pendingRemoval = doc }
            } label: { Image(systemName: "ellipsis").padding(8) }.disabled(library.isBusy)
        }.padding(16).background(FlowStyle.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct CropImage: View {
    let url: URL?
    let rect: UnitRect
    var targetWidth = 1200
    @State private var image: UIImage?
    @State private var failed = false
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else if failed { Image(systemName: "photo.badge.exclamationmark").foregroundStyle(.secondary) }
            else { ProgressView().tint(.gray).frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .task(id: "\(url?.path ?? "")-\(rect)-\(targetWidth)") {
            guard let url else { return }
            image = nil; failed = false
            do {
                let loaded = try await CropLoader.shared.image(url: url, rect: rect, width: targetWidth)
                try Task.checkCancellation()
                image = loaded
            } catch is CancellationError {} catch { failed = true }
        }
        .onDisappear { image = nil }
    }
}
