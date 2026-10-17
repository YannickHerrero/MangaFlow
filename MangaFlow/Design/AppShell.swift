import SwiftUI

struct AppShell: View {
  @Bindable var library: LibraryModel
  @Bindable var remote: RemoteModel
  @Binding var tab: Int
  @Environment(\.palette) private var p
  var body: some View {
    ZStack {
      ThemeBackground()
      Group {
        switch tab {
        case 1: ExplorerView(remote: remote, library: library)
        case 2: ActivityView(remote: remote, library: library)
        default: SeriesLibraryView(library: library, remote: remote)
        }
      }
    }.safeAreaInset(edge: .bottom, spacing: 0) { ThemeTabBar(selection: $tab, count: activeCount) }
      .onChange(of: remote.jobs.count) { _, _ in reconcile() }
      .onChange(of: remote.connected) { _, _ in reconcile() }
  }
  private var activeCount: Int {
    remote.jobs.filter { $0.kind == "download" && !$0.finished }.count + (remote.importing ? 1 : 0)
      + (library.isBusy && !remote.importing ? 1 : 0)
  }
  private func reconcile() {
    if let id = remote.connection?.serverID {
      library.reconcile(jobs: remote.jobs, serverID: id, sources: remote.sources)
    }
  }
}
