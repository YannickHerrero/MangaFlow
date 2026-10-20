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
            .themedNavigation("Connexion au Mac")
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
    @Environment(FavoriteStore.self) private var favorites
    @Bindable var remote: RemoteModel
    let source: RemoteSource
    let library: LibraryModel
    @AppStorage("favoriteSources") private var favoriteSources = "[]"
    @State private var mangas: [RemoteManga] = []
    @State private var search = ""
    @State private var searching = false
    @State private var total = 0
    @State private var loading = false
    @State private var showInfo = false
    private var current: RemoteSource { remote.sources.first { $0.id == source.id } ?? source }
    private var saved: Bool { SourceFavorites.contains(favoriteSources, server: remote.connection?.serverID, source: source.id) }
    private var followed: Int { favorites.items.filter { $0.serverID == remote.connection?.serverID && $0.manga.sourceID == source.id }.count }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    RoundBackButton(); Spacer()
                    RoundIconButton(symbol: saved ? "star.fill" : "star", label: saved ? "Retirer la source des favoris" : "Ajouter la source aux favoris") {
                        favoriteSources = SourceFavorites.toggled(favoriteSources, server: remote.connection?.serverID, source: source.id)
                    }.foregroundStyle(saved ? Color(hex: 0xCA8A04) : p.ink)
                    RoundIconButton(symbol: "magnifyingglass", label: "Rechercher dans le catalogue") { searching.toggle() }
                    Menu {
                        Button(current.catalog.state == "syncing" ? "Synchronisation en cours…" : "Actualiser le catalogue") { Task { await remote.synchronize(current) } }
                            .disabled(current.catalog.state == "syncing" || !remote.connected).accessibilityIdentifier("syncCatalog")
                        Button("Informations sur le catalogue") { showInfo = true }
                    } label: { Image(systemName: "ellipsis").font(.system(size: 18)).frame(width: 44, height: 44).background(p.surface, in: Circle()).overlay(Circle().stroke(p.line, lineWidth: 1)) }
                        .accessibilityLabel("Options de la source").accessibilityIdentifier("sourceOptions")
                }.padding(.bottom, 18)
                Text(source.name).font(p.font(26, title: true)).padding(.bottom, 4)
                (Text(SourceFavorites.languages(source.languages) + " · ").foregroundStyle(p.muted)
                 + Text(SourceFavorites.followedLabel(followed)).foregroundStyle(p.accent).fontWeight(.semibold)).font(p.font(14)).padding(.bottom, 20)
                if searching || !search.isEmpty {
                    SourceSearchField(placeholder: "Rechercher dans le catalogue local", text: $search).accessibilityIdentifier("catalogSearch").padding(.bottom, 18)
                }
                HStack(spacing: 8) {
                    sortChip("Populaires", available: false)
                    sortChip("Récents", available: false)
                    sortChip("A–Z", available: true)
                }.padding(.bottom, 18)
                if !current.capabilities.catalog {
                    Text("Cette source ne fournit pas de catalogue complet.").font(p.font(13)).foregroundStyle(p.muted).padding(.vertical, 12)
                } else if current.catalog.syncedAt == nil {
                    Text("Synchronise le catalogue local avant de rechercher un manga.").font(p.font(13)).foregroundStyle(p.muted)
                    Button("Synchroniser le catalogue") { Task { await remote.synchronize(current) } }.disabled(!remote.connected || current.catalog.state == "syncing").padding(.vertical, 12).accessibilityIdentifier("syncCatalogInitial")
                } else {
                    Text(current.catalog.state == "syncing" ? "Actualisation en cours…" : "Catalogue local du Mac").font(p.font(12)).foregroundStyle(p.muted).padding(.bottom, 8)
                }
                if current.catalog.lastError != nil { Text("Dernière actualisation échouée · catalogue précédent conservé").font(p.font(12)).foregroundStyle(p.danger).padding(.bottom, 8) }
                if !remote.connected { Text("Mac injoignable").font(p.font(13)).foregroundStyle(p.muted) }
                ForEach(mangas) { manga in catalogRow(manga) }
                if loading { ProgressView().frame(maxWidth: .infinity).padding() }
                if !loading && mangas.isEmpty && current.catalog.syncedAt != nil { Text(search.isEmpty ? "Catalogue vide." : "Aucun manga trouvé.").font(p.font(13)).foregroundStyle(p.muted).padding(.vertical, 12) }
                if mangas.count < total { Button("Charger la suite (\(mangas.count) / \(total))") { Task { await load(more: true) } }.disabled(loading).padding(.vertical, 16) }
            }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 28).frame(maxWidth: 800).frame(maxWidth: .infinity)
        }.sourcePage()
            .task(id: search) { do { try await Task.sleep(for: .milliseconds(300)); await load() } catch {} }
            .onChange(of: current.catalog.syncedAt) { _, _ in Task { await load() } }
            .onChange(of: remote.connected) { _, connected in if connected { Task { await load() } } }
            .alert("Catalogue de \(source.name)", isPresented: $showInfo) { Button("Fermer", role: .cancel) {} } message: {
                Text("La recherche porte sur le catalogue local synchronisé sur le Mac, pas sur le site en direct.\n\nDernière synchronisation : \(syncDate)\n\nCette source ne fournit ni classement de popularité ni date de parution pour les mangas. Seul le tri A–Z est disponible." + (current.catalog.lastError.map { "\n\n" + $0.localizedDescription } ?? ""))
            }
    }
    private var syncDate: String {
        RemoteJob.timestamp(current.catalog.syncedAt)?.formatted(date: .abbreviated, time: .shortened) ?? "Jamais"
    }
    private func sortChip(_ title: String, available: Bool) -> some View {
        Text(title).font(p.font(14)).fontWeight(available ? .semibold : .regular).padding(.horizontal, 16).frame(minHeight: 36)
            .foregroundStyle(available ? p.paper : p.muted).background(available ? p.ink : p.surface, in: Capsule()).overlay(Capsule().stroke(p.line, lineWidth: available ? 0 : 1))
            .opacity(available ? 1 : 0.55).accessibilityLabel(available ? "Tri alphabétique sélectionné" : "\(title), indisponible pour cette source")
    }
    private func catalogRow(_ manga: RemoteManga) -> some View {
        let index = MangaLibraryIndex(library: library, server: remote.connection?.serverID, manga: manga)
        let saved = remote.connection.map { favorites.contains(manga, serverID: $0.serverID) } ?? false
        let chapters = remote.jobs.first { $0.kind == "chapters" && $0.target.manga == manga && $0.result?.chapters != nil }?.result?.chapters?.count
        return HStack(alignment: .top, spacing: 14) {
            ListDot(active: index.unread)
            NavigationLink { MangaChaptersView(remote: remote, manga: manga, library: library) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(manga.title).font(p.font(16)).fontWeight(.medium)
                    if let chapters { Text("\(chapters) chapitres").font(p.font(13)).foregroundStyle(p.muted) }
                    if !index.chapterIDs.isEmpty { Label("\(index.chapterIDs.count) dans la bibliothèque", systemImage: "checkmark").font(p.font(13)).fontWeight(.medium).foregroundStyle(p.green) }
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("manga-\(manga.id)")
            FavoriteStar(saved: saved) {
                guard let serverID = remote.connection?.serverID else { return }
                do { try favorites.toggle(manga, sourceName: source.name, serverID: serverID) } catch { remote.report(error) }
            }
        }.padding(.vertical, 10)
    }
    private func load(more: Bool = false) async {
        guard current.catalog.syncedAt != nil, let client = remote.client, remote.connected else { return }
        let requestedSearch = search
        loading = true; defer { loading = false }
        do {
            let (items, count) = try await client.catalog(source.id, query: search, offset: more ? mangas.count : 0)
            guard requestedSearch == search, !Task.isCancelled else { return }
            if more { mangas += items } else { mangas = items }; total = count
        } catch is CancellationError {} catch { remote.report(error) }
    }
}
struct MangaChaptersView: View {
    @Environment(\.palette) private var p
    @Environment(FavoriteStore.self) private var favorites
    @Environment(MetadataStore.self) private var metadata
    @Bindable var remote: RemoteModel
    let manga: RemoteManga
    let library: LibraryModel
    @AppStorage("explorerHideReadChapters") private var hideRead = false
    @State private var jobID: String?
    @State private var starting = false
    @State private var ascending = false
    @State private var confirmingBatch = false
    private var job: RemoteJob? { remote.jobs.first { $0.id == jobID } ?? remote.jobs.first { $0.kind == "chapters" && $0.target.sourceID == manga.sourceID && $0.target.manga?.id == manga.id && $0.result?.chapters != nil } }
    private var chapters: [RemoteChapter] { job?.result?.chapters ?? [] }
    private var index: MangaLibraryIndex { MangaLibraryIndex(library: library, server: remote.connection?.serverID, manga: manga) }
    private var readBoundary: Decimal? { ChapterListFilter.readBoundary(documents: library.allDocuments, serverID: remote.connection?.serverID, manga: manga, chapters: chapters) }
    private var visibleChapters: [RemoteChapter] {
        let items = ChapterListFilter.remote(chapters, boundary: hideRead ? readBoundary : nil, mangaTitle: manga.title)
        return ascending ? Array(items.reversed()) : items
    }
    private var pending: [BatchDownloadEntry] { remote.batchEntries(for: manga) }
    private var remaining: [RemoteChapter] {
        let local = index.chapterIDs, sending = Set(pending.map { $0.chapter.id })
        return chapters.filter { chapter in
            guard !local.contains(chapter.id), !sending.contains(chapter.id) else { return false }
            guard let job = remote.downloadJob(for: manga, chapter: chapter) else { return true }
            return job.finished && !(job.state == "completed" && remote.isAwaitingImport(job))
        }
    }
    private var saved: Bool { remote.connection.map { favorites.contains(manga, serverID: $0.serverID) } ?? false }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    RoundBackButton(); Spacer()
                    RoundIconButton(symbol: saved ? "star.fill" : "star", label: saved ? "Retirer des favoris" : "Ajouter aux favoris", action: toggleFavorite)
                        .foregroundStyle(saved ? Color(hex: 0xCA8A04) : p.ink).accessibilityIdentifier("toggleFavorite")
                    Menu {
                        Toggle("Masquer les chapitres lus", isOn: $hideRead).accessibilityIdentifier("explorerHideReadChapters")
                        Toggle("Chapitres croissants", isOn: $ascending)
                        Button("Actualiser les chapitres") { Task { await load() } }.disabled(!remote.connected)
                    } label: { Image(systemName: "ellipsis").font(.system(size: 18)).frame(width: 44, height: 44).background(p.surface, in: Circle()).overlay(Circle().stroke(p.line, lineWidth: 1)) }
                        .accessibilityLabel("Options des chapitres").accessibilityIdentifier("chapterOptions")
                }.padding(.bottom, 18)
                Text(manga.title).font(p.font(26, title: true)).padding(.bottom, 6)
                HStack(spacing: 8) {
                    if saved { Text("Suivi").font(p.font(12)).fontWeight(.medium).foregroundStyle(p.green).padding(.horizontal, 10).padding(.vertical, 4).background(p.green.opacity(0.1), in: Capsule()) }
                    Text((chapters.isEmpty ? "" : "\(chapters.count) chapitres · ") + (remote.sources.first { $0.id == manga.sourceID }?.name ?? manga.sourceID)).font(p.font(13)).foregroundStyle(p.muted)
                }.padding(.bottom, 20)
                if !chapters.isEmpty { librarySummary.padding(.bottom, 22) }
                if hideRead { Text(readBoundary.map { "À partir du chapitre \(NSDecimalNumber(decimal: $0).stringValue), inclus" } ?? "Aucun chapitre terminé connu pour cette source").font(p.font(12)).foregroundStyle(p.muted).padding(.bottom, 12) }
                if starting || (job != nil && job?.finished == false) { ProgressView("Chargement des chapitres…").padding(.vertical, 12) }
                if let error = job?.error { Text(error.localizedDescription).font(p.font(13)).foregroundStyle(p.danger).padding(.bottom, 12) }
                if !remote.connected { Text("Mac injoignable · chapitres déjà importés disponibles hors ligne").font(p.font(13)).foregroundStyle(p.muted).padding(.bottom, 12) }
                if job?.state == "completed" && visibleChapters.isEmpty { Text(hideRead ? "Aucun chapitre à afficher avec ce filtre." : "Aucun chapitre disponible.").font(p.font(13)).foregroundStyle(p.muted) }
                ForEach(visibleChapters) { chapter in ChapterDownloadRow(remote: remote, library: library, manga: manga, chapter: chapter) }
            }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 28).frame(maxWidth: 800).frame(maxWidth: .infinity)
        }.sourcePage().task(id: remote.connected) { await load() }
            .confirmationDialog("Ajouter \(remaining.count) chapitres à la bibliothèque ?", isPresented: $confirmingBatch, titleVisibility: .visible) {
                Button("Ajouter les chapitres restants") {
                    remote.enqueueDownloads(manga, chapters: remaining)
                    Task { await remote.submitBatchDownloads() }
                }
            } message: { Text("Les chapitres seront téléchargés sur le Mac et importés automatiquement. Les envois non terminés reprendront à la prochaine ouverture de l’application.") }
    }
    private var librarySummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dans la bibliothèque").font(p.font(16, title: true))
            (Text("\(index.chapterIDs.intersection(Set(chapters.map(\.id))).count)").fontWeight(.semibold) + Text(" sur \(chapters.count) chapitres · \(remaining.count) à ajouter").foregroundStyle(p.muted)).font(p.font(14))
            ProgressView(value: Double(index.chapterIDs.intersection(Set(chapters.map(\.id))).count), total: Double(max(1, chapters.count))).tint(p.accent)
            if !pending.isEmpty {
                Text("\(pending.count) demande\(pending.count > 1 ? "s" : "") à envoyer au Mac").font(p.font(13)).foregroundStyle(p.muted)
                if let error = pending.compactMap(\.error).first {
                    Text(error).font(p.font(12)).foregroundStyle(p.danger)
                    Button("Réessayer l’envoi du lot") { remote.automaticImports.retryBatch(serverID: remote.connection?.serverID ?? "", manga: manga); Task { await remote.submitBatchDownloads() } }
                }
                Button("Annuler les envois restants") { remote.automaticImports.cancelBatch(serverID: remote.connection?.serverID ?? "", manga: manga) }
            }
            if !remaining.isEmpty {
                Button { confirmingBatch = true } label: {
                    Text("Ajouter les \(remaining.count) chapitres restants").font(p.font(14)).fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(p.paper).background(p.ink, in: Capsule())
                }.buttonStyle(.plain).disabled(!remote.connected).accessibilityIdentifier("downloadRemaining")
            } else if pending.isEmpty { Text("Tous les chapitres sont ajoutés ou en cours d’ajout.").font(p.font(13)).foregroundStyle(p.green) }
        }.padding(16).background(p.surface, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(p.line, lineWidth: 1))
    }
    private func load() async {
        guard let client = remote.client, remote.connected else { return }
        starting = true; defer { starting = false }
        do { let created = try await client.create("chapters", target: .init(sourceID: manga.sourceID, manga: manga, chapter: nil)); jobID = created.id; await remote.refresh() }
        catch is CancellationError {} catch { remote.report(error) }
    }
    private func toggleFavorite() {
        guard let serverID = remote.connection?.serverID else { return }
        do { try favorites.toggle(manga, sourceName: remote.sources.first { $0.id == manga.sourceID }?.name ?? manga.sourceID, serverID: serverID) } catch { remote.report(error) }
    }
}
