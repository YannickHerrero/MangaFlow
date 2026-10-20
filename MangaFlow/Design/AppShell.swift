import SwiftUI

struct AppShell: View {
    @Bindable var library: LibraryModel
    @Bindable var remote: RemoteModel
    @Binding var tab: Int
    @Environment(\.palette) private var p
    var body: some View {
        TabView(selection: $tab) {
            Tab("Bibliothèque", systemImage: "books.vertical", value: 0) {
                SeriesLibraryView(library: library, remote: remote)
            }
            Tab("Explorer", systemImage: "safari", value: 1) {
                ExplorerView(remote: remote, library: library)
            }
        }.tabViewStyle(.tabBarOnly).tint(p.accent)
            .onChange(of: remote.jobs.count) { _, _ in reconcile() }
            .onChange(of: remote.connected) { _, _ in reconcile() }
    }
    private func reconcile() {
        if let id = remote.connection?.serverID { library.reconcile(jobs: remote.jobs, serverID: id, sources: remote.sources) }
    }
}
