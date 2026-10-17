import SwiftUI

struct AppShell: View {
  @Bindable var library: LibraryModel
  @Bindable var remote: RemoteModel
  @Binding var tab: Int
  @Environment(\.palette) private var p
  var body: some View {
    // Reserve real layout space for the bar. An inset outside NavigationStack
    // can be lost when a pushed destination establishes its own safe area.
    VStack(spacing: 0) {
      Group {
        switch tab {
        case 1: ExplorerView(remote: remote, library: library)
        case 2: ActivityView(remote: remote, library: library)
        default: SeriesLibraryView(library: library, remote: remote)
        }
      }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
      ThemeTabBar(selection: $tab, count: activeCount)
    }.background { ThemeBackground() }
      .onChange(of: remote.jobs.count) { _, _ in reconcile() }
      .onChange(of: remote.connected) { _, _ in reconcile() }
  }
  private var activeCount: Int {
    remote.activeDownloadCount
      + (library.isBusy && !remote.importing ? 1 : 0)
  }
  private func reconcile() {
    if let id = remote.connection?.serverID {
      library.reconcile(jobs: remote.jobs, serverID: id, sources: remote.sources)
    }
  }
}
