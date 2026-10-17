import SwiftUI

struct FavoritesView: View {
    @Environment(\.palette) private var p
    @Bindable var remote: RemoteModel
    let library: LibraryModel
    @Environment(FavoriteStore.self) private var favorites
    var body: some View {
        NavigationStack {
            List {
                if let error = favorites.loadError { Text(error).foregroundStyle(.orange) }
                if favorites.items.isEmpty && favorites.loadError == nil {
                    ContentUnavailableView("Tes mangas favoris", systemImage: "heart", description: Text("Ouvre un manga depuis Sources, puis touche le cœur pour le retrouver ici."))
                }
                ForEach(favorites.items) { favorite in
                    if remote.connection?.serverID == favorite.serverID {
                        NavigationLink {
                            MangaChaptersView(remote: remote, manga: favorite.manga, library: library)
                        } label: { favoriteLabel(favorite) }
                        .accessibilityIdentifier("favorite-\(favorite.manga.sourceID)-\(favorite.manga.id)")
                        .swipeActions { removeButton(favorite) }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            favoriteLabel(favorite)
                            Text("Relie cet appareil au Mac d’origine pour consulter ce favori.").font(.caption).foregroundStyle(.secondary)
                        }.swipeActions { removeButton(favorite) }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(p.paper)
            .navigationTitle("Favoris")
        }
    }
    private func favoriteLabel(_ favorite: FavoriteManga) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(favorite.manga.title).font(.headline)
            Text(favorite.sourceName).font(.caption).foregroundStyle(.secondary)
        }
    }
    private func removeButton(_ favorite: FavoriteManga) -> some View {
        Button("Retirer", systemImage: "heart.slash", role: .destructive) {
            do { try favorites.remove(favorite) } catch { remote.report(error) }
        }
    }
}
