import SwiftUI

struct ExplorerView: View {
  @Bindable var remote: RemoteModel
  let library: LibraryModel
  @Environment(FavoriteStore.self) private var favorites
  @Environment(\.palette) private var p
  @State private var search = ""
  @FocusState private var searchFocused: Bool
  @State private var connection = false
  @AppStorage("favoriteSources") private var favoriteSources = "[]"
  private var keys: [String] {
    (try? JSONDecoder().decode([String].self, from: Data(favoriteSources.utf8))) ?? []
  }
  private func key(_ source: RemoteSource) -> String {
    ChapterOrigin.key(remote.connection?.serverID ?? "", source.id, "")
  }
  private func saved(_ source: RemoteSource) -> Bool { keys.contains(key(source)) }
  private var sources: [RemoteSource] {
    remote.sources.filter {
      search.isEmpty
        || ($0.name + " " + $0.languages.joined(separator: " ") + " "
          + $0.tags.joined(separator: " ")).localizedCaseInsensitiveContains(search)
    }
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          ThemeHeader(
            title: p.theme == .brutal ? "Explorer / \(remote.sources.count) sources" : "Explorer",
            remote: remote, library: library)
          Text(
            p.theme == .brutal
              ? "TROU\nVER." : p.theme == .manga ? "Quoi lire ensuite ?!" : "Trouver\nla suite."
          ).font(p.font(p.theme == .brutal ? 70 : 42, title: true)).tracking(-1.5)
          HStack {
            Image(systemName: "magnifyingglass")
            TextField("Source ou manga favori", text: $search).focused($searchFocused).submitLabel(
              .search
            ).onSubmit { searchFocused = false }
          }.themeCard().accessibilityIdentifier("explorerSearch")
          Button {
            connection = true
          } label: {
            Label(
              remote.connection == nil
                ? "Connecter le Mac" : remote.connected ? "Mac connecté" : "Mac injoignable",
              systemImage: remote.connected ? "checkmark.circle" : "network")
          }.buttonStyle(.plain)
          if !remote.connected {
            Text(
              "Le Mac doit être allumé et joignable. Les chapitres importés restent lisibles hors ligne."
            ).font(p.font(12))
          }
          Text("Mangas favoris").font(p.font(20, title: true))
          if let error = favorites.loadError { Text(error).foregroundStyle(.orange) }
          if favorites.items.isEmpty {
            Text("Ajoute un manga avec le cœur depuis sa liste de chapitres.").font(p.font(13))
          }
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
              ForEach(
                favorites.items.filter {
                  search.isEmpty || $0.manga.title.localizedCaseInsensitiveContains(search)
                }
              ) { fav in
                VStack(alignment: .leading, spacing: 6) {
                  if remote.connection?.serverID == fav.serverID {
                    NavigationLink {
                      MangaChaptersView(remote: remote, manga: fav.manga, library: library)
                    } label: {
                      favoriteTile(fav)
                    }.buttonStyle(.plain).accessibilityIdentifier(
                      "favorite-\(fav.manga.sourceID)-\(fav.manga.id)")
                  } else {
                    favoriteTile(fav)
                    Text("Reconnecte le Mac d’origine").font(p.font(10))
                  }
                }.contextMenu {
                  Button("Retirer des favoris", role: .destructive) {
                    do { try favorites.remove(fav) } catch { remote.report(error) }
                  }
                }
              }
            }
          }
          if sources.contains(where: saved) {
            Text("Sources favorites").font(p.font(20, title: true))
            ForEach(sources.filter(saved)) { source in sourceRow(source, featured: true) }
          }
          Text("Toutes les sources").font(p.font(20, title: true))
          ForEach(sources) { source in sourceRow(source) }
          if sources.isEmpty && remote.connection != nil {
            Text("Aucune source à afficher.")
            Button("Actualiser") { Task { await remote.refresh() } }
          }
        }.padding(p.theme == .brutal ? 14 : 18).padding(.bottom, 24).frame(maxWidth: 850).frame(
          maxWidth: .infinity)
      }.scrollDismissesKeyboard(.interactively).background { ThemeBackground() }.toolbar(
        .hidden, for: .navigationBar
      ).refreshable { await remote.refresh() }
        .sheet(isPresented: $connection) {
          NavigationStack {
            ConnectionView(remote: remote, library: library).toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button("Fermer") { connection = false }
              }
            }
          }
        }
    }
  }
  private func favoriteTile(_ fav: FavoriteManga) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      SeriesCover(
        key: ChapterOrigin.key(fav.serverID, fav.manga.sourceID, fav.manga.id),
        title: fav.manga.title
      ).frame(width: 110, height: 155).clipShape(RoundedRectangle(cornerRadius: p.radius))
      Text(fav.manga.title).font(p.font(14, title: true)).lineLimit(1)
      Text(fav.sourceName).font(p.font(11))
    }.frame(width: 110, alignment: .leading)
  }
  private func sourceRow(_ source: RemoteSource, featured: Bool = false) -> some View {
    HStack {
      NavigationLink {
        SourceCatalogView(remote: remote, source: source, library: library)
      } label: {
        HStack(spacing: 12) {
          Text(String(source.name.prefix(1))).font(p.font(24, title: true)).frame(
            width: 44, height: 44
          ).background(p.accent.opacity(0.18), in: RoundedRectangle(cornerRadius: p.radius))
          VStack(alignment: .leading, spacing: 4) {
            Text(source.name).font(p.font(16, title: true))
            Text(status(source)).font(p.font(11))
            if let explanation = source.explanation {
              Text(explanation).font(p.font(10)).lineLimit(2)
            }
          }
          Spacer()
        }
      }.buttonStyle(.plain).accessibilityIdentifier(
        "\(featured ? "featured-source" : "source")-\(source.id)")
      Button {
        var updated = keys
        let id = key(source)
        if let index = updated.firstIndex(of: id) {
          updated.remove(at: index)
        } else {
          updated.append(id)
        }
        if let data = try? JSONEncoder().encode(updated) {
          favoriteSources = String(decoding: data, as: UTF8.self)
        }
      } label: {
        Image(systemName: saved(source) ? "star.fill" : "star").padding(10)
      }.accessibilityLabel(
        saved(source) ? "Retirer la source des favoris" : "Ajouter la source aux favoris")
    }.themeCard()
  }
  private func status(_ source: RemoteSource) -> String {
    if !source.capabilities.catalog { return "Sans catalogue complet" }
    if source.catalog.state == "syncing" { return "Synchronisation…" }
    if source.catalog.lastError != nil { return "Dernière synchronisation échouée" }
    if let date = source.catalog.syncedAt {
      return "\(source.catalog.count ?? 0) mangas · \(date.prefix(10))"
    }
    return "À charger"
  }
}
