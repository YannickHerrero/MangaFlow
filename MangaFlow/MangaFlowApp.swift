import SwiftUI

@main
struct MangaFlowApp: App {
    @State private var library = LibraryModel()
    @State private var remote = RemoteModel()
    @State private var favorites = FavoriteStore()
    @State private var theme = ThemeSettings()
    @State private var metadata = MetadataStore()
    @State private var tab = 0
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            ThemeHost {
                AppShell(library: library, remote: remote, tab: $tab)
            }
                .environment(theme)
                .environment(metadata)
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
                ThemeHost {
                    ReaderView(document: document, store: library.store, onPosition: { panel in
                        library.remember(documentID: document.id, panelID: panel)
                    }, nextChapter: nextChapter(after: document))
                }.environment(theme).environment(metadata)
            }
                .preferredColorScheme(theme.scheme)

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
    private func nextChapter(after document: MangaDocument) -> (() -> Void)? {
        guard let series = library.series.first(where: { $0.id == document.seriesID }),
              let index = series.documents.firstIndex(where: { $0.id == document.id }),
              series.documents.indices.contains(index + 1) else { return nil }
        let next = series.documents[index + 1]
        return {
            library.selected = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                library.open(next)
            }
        }
    }

}
