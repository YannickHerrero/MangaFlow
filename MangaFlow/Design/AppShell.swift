import SwiftUI

struct HideMainTabsKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}
struct AppShell: View {
    @Bindable var library: LibraryModel
    @Bindable var remote: RemoteModel
    @Binding var tab: Int
    @Environment(\.palette) private var p
    @State private var hideLibraryTabs = false
    @State private var hideExplorerTabs = false
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $tab) {
                Tab("Bibliothèque", systemImage: "books.vertical", value: 0) {
                    SeriesLibraryView(library: library, remote: remote)
                        .onPreferenceChange(HideMainTabsKey.self) { hideLibraryTabs = $0 }
                        .toolbar(.hidden, for: .tabBar)
                }
                Tab("Explorer", systemImage: "safari", value: 1) {
                    ExplorerView(remote: remote, library: library)
                        .onPreferenceChange(HideMainTabsKey.self) { hideExplorerTabs = $0 }
                        .toolbar(.hidden, for: .tabBar)
                }
            }.tabViewStyle(.tabBarOnly).tint(p.accent).frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
            if !(tab == 0 ? hideLibraryTabs : hideExplorerTabs) { wideTabs }
        }.background(p.paper.ignoresSafeArea())
            .onChange(of: remote.jobs.count) { _, _ in reconcile() }
            .onChange(of: remote.connected) { _, _ in reconcile() }
    }
    private var wideTabs: some View {
        HStack(spacing: 6) {
            ForEach(0..<2) { index in
                Button { tab = index } label: {
                    HStack(spacing: 8) {
                        Image(systemName: index == 0 ? "books.vertical" : "safari").font(.system(size: 19))
                        Text(index == 0 ? "Bibliothèque" : "Explorer").font(p.font(15)).fontWeight(tab == index ? .semibold : .medium)
                    }.foregroundStyle(tab == index ? p.ink : p.muted).frame(maxWidth: .infinity, minHeight: 46)
                        .background(tab == index ? p.chip.opacity(0.8) : .clear, in: Capsule()).contentShape(Capsule())
                }.buttonStyle(.plain).accessibilityIdentifier("tab-\(index)").accessibilityLabel(index == 0 ? "Bibliothèque" : "Explorer")
                    .accessibilityAddTraits(tab == index ? .isSelected : [])
            }
        }.padding(6).glassEffect(.regular, in: Capsule()).padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 8)
    }
    private func reconcile() {
        if let id = remote.connection?.serverID { library.reconcile(jobs: remote.jobs, serverID: id, sources: remote.sources) }
    }
}
