import SwiftUI
import UniformTypeIdentifiers

struct ExplorerView: View {
    @Bindable var remote: RemoteModel
    let library: LibraryModel
    @Environment(FavoriteStore.self) private var favorites
    @Environment(\.palette) private var p
    @State private var search = ""
    @State private var importer = false
    @State private var filters = false
    @State private var language = ""
    @State private var catalogOnly = false
    @AppStorage("explorerFavoriteKind") private var favoriteKind = "mangas"
    @AppStorage("favoriteSources") private var favoriteSources = "[]"
    private var sources: [RemoteSource] {
        remote.sources.filter {
            (search.isEmpty || ($0.name + " " + SourceFavorites.languages($0.languages)).localizedCaseInsensitiveContains(search)) &&
            (language.isEmpty || $0.languages.contains(language)) && (!catalogOnly || $0.capabilities.catalog)
        }
    }
    private func saved(_ source: RemoteSource) -> Bool { SourceFavorites.contains(favoriteSources, server: remote.connection?.serverID, source: source.id) }
    private var favoriteSourceCount: Int { remote.sources.filter(saved).count }
    private var books: [FavoriteManga] { favorites.items.filter { search.isEmpty || ($0.manga.title + " " + $0.sourceName).localizedCaseInsensitiveContains(search) } }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ThemeHeader(title: "Explorer", settingsImport: { importer = true }, filtering: { filters = true }, remote: remote, library: library).padding(.bottom, 18)
                    Text("Explorer").font(p.font(26, title: true)).padding(.bottom, 20)
                    SourceSearchField(placeholder: "Manga ou source…", text: $search).accessibilityIdentifier("explorerSearch").padding(.bottom, 26)
                    HStack {
                        Text("Favoris").font(p.font(14)).fontWeight(.medium).foregroundStyle(p.muted)
                        Spacer(minLength: 8)
                        HStack(spacing: 2) {
                            favoriteSegment("mangas", "Mangas", favorites.items.count)
                            favoriteSegment("sources", "Sources", favoriteSourceCount)
                        }.padding(3).background(p.chip, in: Capsule())
                    }.padding(.bottom, 10)
                    VStack(alignment: .leading, spacing: 0) {
                    if favoriteKind == "sources" {
                        let items = sources.filter(saved)
                        if items.isEmpty { emptyFavorites("Ajoute une source aux favoris avec son étoile.") }
                        ForEach(items) { sourceRow($0, featured: true) }
                    } else {
                        if books.isEmpty { emptyFavorites(search.isEmpty ? "Retrouve ici les mangas ajoutés aux favoris." : "Aucun manga favori ne correspond à cette recherche.") }
                        ForEach(books) { favoriteRow($0) }
                    }
                    }
                    Text("Toutes les sources").font(p.font(14)).fontWeight(.medium).foregroundStyle(p.muted).padding(.top, 22).padding(.bottom, 8)
                    ForEach(sources) { sourceRow($0) }
                    if remote.connection == nil {
                        Text("Relie ton Mac depuis Réglages → Connexion au Mac pour accéder aux sources.").font(p.font(13)).foregroundStyle(p.muted).padding(.vertical, 12)
                    } else if !remote.connected {
                        Text("Mac injoignable · dernières sources enregistrées. Tes chapitres locaux restent lisibles.").font(p.font(13)).foregroundStyle(p.muted).padding(.vertical, 12)
                    }
                    if sources.isEmpty && remote.connection != nil {
                        Text("Aucune source ne correspond aux filtres.").font(p.font(13)).foregroundStyle(p.muted).padding(.vertical, 12)
                        Button("Actualiser les sources") { Task { await remote.refresh() } }
                    }
                    if let error = favorites.loadError { Text(error).font(p.font(13)).foregroundStyle(p.danger) }
                }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 24).frame(maxWidth: 800).frame(maxWidth: .infinity)
            }.background(p.paper).toolbar(.hidden, for: .navigationBar).scrollDismissesKeyboard(.interactively)
                .refreshable { await remote.refresh() }
                .fileImporter(isPresented: $importer, allowedContentTypes: [.zip, UTType(filenameExtension: "cbz") ?? .zip]) { result in
                    do { library.importCBZ(try result.get()) } catch { remote.report(error) }
                }
                .sheet(isPresented: $filters) {
                    ThemeHost {
                        NavigationStack {
                            Form {
                                Picker("Langue", selection: $language) {
                                    Text("Toutes les langues").tag("")
                                    ForEach(Array(Set(remote.sources.flatMap(\.languages))).sorted(), id: \.self) { Text(SourceFavorites.languages([$0])).tag($0) }
                                }
                                Toggle("Sources avec catalogue complet", isOn: $catalogOnly)
                                Button("Réinitialiser les filtres") { language = ""; catalogOnly = false }
                            }.navigationTitle("Filtres").toolbar { Button("Fermer") { filters = false } }
                        }
                    }.presentationDetents([.medium]).presentationCornerRadius(30).presentationDragIndicator(.visible)
                }
        }
    }
    private func favoriteSegment(_ value: String, _ title: String, _ count: Int) -> some View {
        Button { favoriteKind = value } label: {
            (Text(title + " ").foregroundStyle(favoriteKind == value ? p.ink : p.muted) + Text("\(count)").foregroundStyle(favoriteKind == value ? p.accent : p.muted))
                .font(p.font(13)).fontWeight(favoriteKind == value ? .semibold : .medium).padding(.horizontal, 10).frame(minHeight: 32)
                .background(favoriteKind == value ? p.surface : .clear, in: Capsule()).contentShape(Capsule())
        }.buttonStyle(.plain).accessibilityIdentifier("favoriteKind-\(value)").accessibilityAddTraits(favoriteKind == value ? .isSelected : [])
    }
    private func emptyFavorites(_ message: String) -> some View { Text(message).font(p.font(13)).foregroundStyle(p.muted).padding(.vertical, 12) }
    private func followed(_ source: RemoteSource) -> Int { favorites.items.filter { $0.serverID == remote.connection?.serverID && $0.manga.sourceID == source.id }.count }
    private func sourceRow(_ source: RemoteSource, featured: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ListDot(active: followed(source) > 0)
            NavigationLink { SourceCatalogView(remote: remote, source: source, library: library) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.name).font(p.font(16)).fontWeight(.medium)
                    Text(SourceFavorites.languages(source.languages) + " · " + (followed(source) > 0 ? SourceFavorites.followedLabel(followed(source)) : "Aucun manga suivi")).font(p.font(13)).foregroundStyle(p.muted)
                    if !source.capabilities.catalog { Text("Catalogue complet indisponible").font(p.font(12)).foregroundStyle(p.muted) }
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("\(featured ? "featured-source" : "source")-\(source.id)")
            FavoriteStar(saved: saved(source)) { favoriteSources = SourceFavorites.toggled(favoriteSources, server: remote.connection?.serverID, source: source.id) }
                .accessibilityIdentifier("favoriteSource-\(source.id)")
        }.padding(.vertical, 10)
    }
    private func favoriteRow(_ favorite: FavoriteManga) -> some View {
        HStack(alignment: .top, spacing: 14) {
            let index = MangaLibraryIndex(library: library, server: favorite.serverID, manga: favorite.manga)
            ListDot(active: index.unread)
            Group {
                if remote.connection?.serverID == favorite.serverID {
                    NavigationLink { MangaChaptersView(remote: remote, manga: favorite.manga, library: library) } label: { favoriteLabel(favorite) }
                        .accessibilityIdentifier("favorite-\(favorite.manga.sourceID)-\(favorite.manga.id)")
                } else { favoriteLabel(favorite) }
            }.buttonStyle(.plain)
            FavoriteStar(saved: true) { do { try favorites.remove(favorite) } catch { remote.report(error) } }
        }.padding(.vertical, 10)
    }
    private func favoriteLabel(_ favorite: FavoriteManga) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(favorite.manga.title).font(p.font(16)).fontWeight(.medium)
            let count = remote.jobs.first { $0.kind == "chapters" && $0.target.manga == favorite.manga && $0.result?.chapters != nil }?.result?.chapters?.count
            Text(favorite.sourceName + (count.map { " · \($0) chapitres" } ?? "") + (remote.connection?.serverID == favorite.serverID ? "" : " · autre Mac")).font(p.font(13)).foregroundStyle(p.muted)
        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
    }
}
