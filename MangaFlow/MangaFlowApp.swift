import SwiftUI

@main
struct MangaFlowApp: App {
    @State private var library = LibraryModel()
    @State private var remote = RemoteModel()
    @State private var favorites = FavoriteStore()
    @State private var tab = 0
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                LibraryView(library: library)
                    .tabItem { Label("Bibliothèque", systemImage: "books.vertical") }.tag(0)
                SourcesView(remote: remote, library: library)
                    .tabItem { Label("Sources", systemImage: "network") }.tag(1)
                FavoritesView(remote: remote, library: library)
                    .tabItem { Label("Favoris", systemImage: "heart") }.tag(2)
            }
                .environment(favorites)
                .alert("Sources", isPresented: Binding(get: { remote.error != nil }, set: { if !$0 { remote.error = nil } })) {
                    Button("Fermer", role: .cancel) { remote.error = nil }
                } message: { Text(remote.error ?? "") }
                .onChange(of: library.selected) { _, selected in if selected != nil { tab = 0 } }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    while !Task.isCancelled {
                        await remote.refresh(silent: true)
                        do { try await Task.sleep(for: .seconds(4)) } catch { return }
                    }
                }
            .fullScreenCover(item: Binding(get: {
                library.documents.first { $0.id == library.selected }
            }, set: { if $0 == nil { library.selected = nil } })) { document in
                ReaderView(document: document, store: library.store) { panel in
                    library.remember(documentID: document.id, panelID: panel)
                }
            }
                .preferredColorScheme(.dark)
                .tint(FlowStyle.accent)
                .onOpenURL { library.importCBZ($0) }
                .task {
                    #if DEBUG
                    let arguments = ProcessInfo.processInfo.arguments
                    if let index = arguments.firstIndex(of: "-import"), arguments.indices.contains(index + 1), !library.isBusy {
                        library.importCBZ(URL(fileURLWithPath: arguments[index + 1]))
                    }
                    if let index = arguments.firstIndex(of: "-pair-file"), arguments.indices.contains(index + 1),
                       let text = try? String(contentsOfFile: arguments[index + 1], encoding: .utf8) {
                        remote.forget()
                        await remote.pair(text)
                        tab = 1
                    }
                    #endif
                }
        }
    }
}
