import SwiftUI
import UniformTypeIdentifiers

struct ConnectionView: View {
    @Environment(\.palette) private var p
    @Bindable var remote: RemoteModel
    let library: LibraryModel
    @State private var pairingText = ""
    @State private var scanner = false
    @State private var filePicker = false
    var body: some View {
            List {
                Section("Connexion au Mac") {
                    if let connection = remote.connection {
                        Label(remote.connected ? "Mac connecté" : "Mac injoignable", systemImage: remote.connected ? "checkmark.circle" : "network.slash")
                        Text(connection.serverURL.host ?? "Mac").font(.caption).foregroundStyle(.secondary)
                        if !remote.connected {
                            Text("Vérifie le Wi-Fi, le serveur et la mise en veille du Mac. Tes mangas importés restent lisibles dans la bibliothèque.").font(.caption)
                            Button("Réessayer") { Task { await remote.refresh() } }
                        }
                        if let status = remote.status {
                            Text("HakuNeko · \(status.engineVersion)").font(.caption)
                            if let error = status.update.lastError { Text("Mise à jour : \(error.message)").font(.caption).foregroundStyle(.orange) }
                        }
                        Menu("Gérer la connexion") {
                            Button("Révoquer cet appareil", role: .destructive) { Task { await remote.revoke() } }
                            Button("Oublier la connexion locale", role: .destructive) { remote.forget() }
                        }
                    } else {
                        Text("Démarre le serveur sur ton Mac, connecte les deux appareils au même réseau local, puis scanne son QR code.").font(.subheadline)
                        Button("Scanner le QR code", systemImage: "qrcode.viewfinder") { scanner = true }
                        DisclosureGroup("Importer ou coller le contenu d’appairage") {
                            Button("Importer le fichier d’appairage", systemImage: "doc") { filePicker = true }
                            TextEditor(text: $pairingText).frame(height: 100).font(.caption.monospaced()).accessibilityIdentifier("pairingPayload")
                            Button("Relier cet appareil") { Task { await remote.pair(pairingText); if remote.connection != nil { pairingText = "" } } }
                                .disabled(remote.busy || pairingText.isEmpty).accessibilityIdentifier("pairServer")
                        }
                        if remote.busy { ProgressView("Appairage…") }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(p.paper)
            .navigationTitle("Connexion au Mac")
            .refreshable { await remote.refresh() }
            .sheet(isPresented: $scanner) { PairingScanner { value in Task { await remote.pair(value) } } }
            .fileImporter(isPresented: $filePicker, allowedContentTypes: [.json, .plainText]) { result in
                do {
                    let url = try result.get(); let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    guard data.count < 16_384, let text = String(data: data, encoding: .utf8) else { return }
                    Task { await remote.pair(text) }
                } catch { remote.report(error) }
            }

    }
}
struct SourceCatalogView: View {
    @Environment(\.palette) private var p
    @Bindable var remote: RemoteModel
    let source: RemoteSource
    let library: LibraryModel
    @State private var mangas: [RemoteManga] = []
    @State private var search = ""
    @FocusState private var searchFocused: Bool
    @State private var total = 0
    @State private var loading = false
    private var current: RemoteSource { remote.sources.first { $0.id == source.id } ?? source }
    var body: some View {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 14) {
            TextField("Rechercher dans le catalogue local", text: $search).focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }
                .textFieldStyle(.plain).padding(14).background(p.surface).accessibilityIdentifier("catalogSearch")
            VStack(alignment: .leading, spacing: 10) {
                Text("Catalogue local du Mac").font(p.font(18, title: true))
                Text("La recherche porte sur le dernier catalogue synchronisé, pas sur le site en direct.").font(.caption)
                if let date = current.catalog.syncedAt { Text("Dernière synchronisation : \(date.prefix(19))").font(.caption) }
                if let error = current.catalog.lastError { Text(error.localizedDescription).font(.caption).foregroundStyle(.orange) }
                if !current.capabilities.catalog { Text(current.explanation ?? "Catalogue indisponible.") }
                else {
                    Button(current.catalog.state == "syncing" ? "Synchronisation en cours…" : "Actualiser le catalogue") { Task { await remote.synchronize(current) } }
                        .disabled(current.catalog.state == "syncing").accessibilityIdentifier("syncCatalog")
                    if current.catalog.syncedAt == nil { Text("Synchronise cette source avant de rechercher un manga.").font(.caption) }
                }
            }
            ForEach(mangas) { manga in
                NavigationLink { MangaChaptersView(remote: remote, manga: manga, library: library) } label: {
                    HStack { Text(manga.title); Spacer(); Image(systemName: "chevron.right") }.themeCard()
                }.buttonStyle(.plain).accessibilityIdentifier("manga-\(manga.id)")
            }
            if loading { ProgressView() }
            if mangas.count < total {
                Button("Charger la suite (\(mangas.count) / \(total))") { Task { await load(more: true) } }
            }
          }.padding(18).frame(maxWidth: 800).frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden).background { ThemeBackground() }
        .themedNavigation(source.name)
        .task(id: search) { do { try await Task.sleep(for: .milliseconds(350)); await load() } catch {} }
        .onChange(of: current.catalog.syncedAt) { _, _ in Task { await load() } }
    }
    private func load(more: Bool = false) async {
        guard current.catalog.syncedAt != nil, let client = remote.client else { return }
        loading = true; defer { loading = false }
        do {
            let (items, count) = try await client.catalog(source.id, query: search, offset: more ? mangas.count : 0)
            if more { mangas += items } else { mangas = items }; total = count
        } catch { remote.report(error) }
    }
}
struct MangaChaptersView: View {
    @Environment(\.palette) private var p
    @Bindable var remote: RemoteModel
    let manga: RemoteManga
    let library: LibraryModel
    @Environment(FavoriteStore.self) private var favorites
    @State private var jobID: String?
    @State private var starting = false
    private var job: RemoteJob? { remote.jobs.first { $0.id == jobID } }
    var body: some View {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(manga.title).font(p.font(28, title: true))
                Spacer()
                favoriteButton
            }
            if starting || (job != nil && job?.finished == false) { ProgressView("Chargement des chapitres sur le Mac…") }
            if let error = job?.error { Text(error.localizedDescription).foregroundStyle(.orange) }
            ForEach(job?.result?.chapters ?? []) { chapter in
                ChapterDownloadRow(remote: remote, library: library, manga: manga, chapter: chapter).themeCard()
            }
          }.padding(18).frame(maxWidth: 800).frame(maxWidth: .infinity)
        }
        .background { ThemeBackground() }.themedNavigation(manga.title)
        .task {
            guard let client = remote.client else { return }
            starting = true; defer { starting = false }
            do {
                let created = try await client.create("chapters", target: .init(sourceID: manga.sourceID, manga: manga, chapter: nil))
                jobID = created.id; await remote.refresh()
            } catch { remote.report(error) }
        }
    }
    @ViewBuilder private var favoriteButton: some View {
        Group {
                if let serverID = remote.connection?.serverID {
                    let saved = favorites.contains(manga, serverID: serverID)
                    Button {
                        do {
                            try favorites.toggle(manga, sourceName: remote.sources.first { $0.id == manga.sourceID }?.name ?? manga.sourceID, serverID: serverID)
                        } catch { remote.report(error) }
                    } label: { Image(systemName: saved ? "heart.fill" : "heart") }
                    .accessibilityLabel(saved ? "Retirer des favoris" : "Ajouter aux favoris")
                    .accessibilityIdentifier("toggleFavorite")
                }
        }
        .buttonStyle(.plain)
    }
}
