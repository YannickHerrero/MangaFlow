import SwiftUI
import UniformTypeIdentifiers

struct ExplorerView: View {
    @Bindable var remote: RemoteModel
    let library: LibraryModel
    @Environment(FavoriteStore.self) private var favorites
    @Environment(\.palette) private var p
    @State private var search = ""
    @State private var importer = false
    @FocusState private var searching: Bool
    @AppStorage("favoriteSources") private var favoriteSources = "[]"
    private var keys: [String] { (try? JSONDecoder().decode([String].self, from: Data(favoriteSources.utf8))) ?? [] }
    private func key(_ source: RemoteSource) -> String { ChapterOrigin.key(remote.connection?.serverID ?? "", source.id, "") }
    private var sources: [RemoteSource] {
        remote.sources.filter { search.isEmpty || ($0.name + " " + $0.languages.joined(separator: " ") + " " + $0.tags.joined(separator: " ")).localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ThemeHeader(title: "Explorer", remote: remote, library: library)
                    Text("Explorer").font(p.font(26, title: true))
                    Text("Tes sources et mangas favoris.").font(p.font(14)).foregroundStyle(p.muted)
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(p.muted)
                        TextField("Source ou manga favori", text: $search).focused($searching).submitLabel(.search).onSubmit { searching = false }
                    }.themeCard().accessibilityIdentifier("explorerSearch")
                    Button { importer = true } label: {
                        HStack { Image(systemName: "doc.badge.plus"); Text("Importer un CBZ"); Spacer(); Image(systemName: "chevron.right").font(.caption) }.contentShape(Rectangle())
                    }.buttonStyle(.plain).themeCard().accessibilityIdentifier("importCBZ")
                    if remote.connection == nil {
                        Text("Pour accéder aux sources, relie ton Mac depuis Réglages → Connexion au Mac.").font(p.font(14)).foregroundStyle(p.muted)
                    } else if !remote.connected {
                        Text("Les sources affichées correspondent à la dernière connexion. Réessaie quand le Mac sera joignable ; les chapitres locaux restent lisibles.").font(p.font(13)).foregroundStyle(p.muted)
                    }
                    if let error = favorites.loadError { Text(error).foregroundStyle(p.danger) }
                    if !favorites.items.isEmpty {
                        Text("Mangas favoris").font(p.font(14)).foregroundStyle(p.muted)
                        ForEach(favorites.items.filter { search.isEmpty || $0.manga.title.localizedCaseInsensitiveContains(search) }) { favorite in
                            if remote.connection?.serverID == favorite.serverID {
                                NavigationLink { MangaChaptersView(remote: remote, manga: favorite.manga, library: library) } label: {
                                    HStack { VStack(alignment: .leading, spacing: 4) { Text(favorite.manga.title).font(p.font(16, title: true)); Text(favorite.sourceName).font(p.font(13)).foregroundStyle(p.muted) }; Spacer(); Image(systemName: "chevron.right").font(.caption) }.contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityIdentifier("favorite-\(favorite.manga.sourceID)-\(favorite.manga.id)")
                                    .contextMenu { Button("Retirer des favoris", role: .destructive) { do { try favorites.remove(favorite) } catch { remote.report(error) } } }
                            } else {
                                Text(favorite.manga.title + " · autre Mac").foregroundStyle(p.muted)
                                    .contextMenu { Button("Retirer des favoris", role: .destructive) { do { try favorites.remove(favorite) } catch { remote.report(error) } } }
                            }
                        }
                    }
                    if sources.contains(where: { keys.contains(key($0)) }) {
                        Text("Sources favorites").font(p.font(14)).foregroundStyle(p.muted)
                        ForEach(sources.filter { keys.contains(key($0)) }) { sourceRow($0, featured: true) }
                    }
                    if !sources.isEmpty { Text("Toutes les sources").font(p.font(14)).foregroundStyle(p.muted) }
                    ForEach(sources) { sourceRow($0) }
                    if sources.isEmpty && remote.connection != nil {
                        Text("Aucune source à afficher.").foregroundStyle(p.muted)
                        Button("Actualiser les sources") { Task { await remote.refresh() } }
                    }
                }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 24).frame(maxWidth: 800).frame(maxWidth: .infinity)
            }.background(p.paper).toolbar(.hidden, for: .navigationBar).scrollDismissesKeyboard(.interactively)
                .refreshable { await remote.refresh() }
                .fileImporter(isPresented: $importer, allowedContentTypes: [.zip, UTType(filenameExtension: "cbz") ?? .zip]) { result in
                    do { library.importCBZ(try result.get()) } catch { remote.report(error) }
                }
        }
    }
    private func sourceRow(_ source: RemoteSource, featured: Bool = false) -> some View {
        HStack(spacing: 12) {
            NavigationLink { SourceCatalogView(remote: remote, source: source, library: library) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.name).font(p.font(16)).fontWeight(.medium)
                        Text(source.languages.joined(separator: " · ")).font(p.font(13)).foregroundStyle(p.muted)
                        if !source.capabilities.catalog { Text(source.explanation ?? "Sans catalogue complet").font(p.font(12)).foregroundStyle(p.muted) }
                    }
                    Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(p.muted)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("\(featured ? "featured-source" : "source")-\(source.id)")
            Button {
                var updated = keys; let id = key(source)
                if let index = updated.firstIndex(of: id) { updated.remove(at: index) } else { updated.append(id) }
                if let data = try? JSONEncoder().encode(updated) { favoriteSources = String(decoding: data, as: UTF8.self) }
            } label: { Image(systemName: keys.contains(key(source)) ? "star.fill" : "star").frame(width: 44, height: 44) }
                .accessibilityLabel(keys.contains(key(source)) ? "Retirer la source des favoris" : "Ajouter la source aux favoris")
        }.padding(.vertical, 4)
    }
}
