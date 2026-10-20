import SwiftUI

struct SettingsView: View {
    let remote: RemoteModel
    let library: LibraryModel
    var onImport: (() -> Void)? = nil
    @Environment(ThemeSettings.self) private var settings
    @Environment(MetadataStore.self) private var metadata
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    @State private var usage = StorageUsage()
    @State private var deleting = false
    @State private var error: String?
    @State private var measuring = false
    private var readCount: Int { library.documents.filter { $0.readComplete == true }.count }
    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Réglages").font(p.font(22, title: true)); Spacer()
                    RoundIconButton(symbol: "xmark", label: "Fermer les réglages") { dismiss() }
                }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if let onImport {
                            section("Import") {
                                Button(action: onImport) {
                                    HStack { Image(systemName: "doc.badge.plus"); Text("Importer un CBZ"); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain).themeCard().accessibilityIdentifier("importCBZ")
                            }
                        }
                        section("Apparence") {
                            HStack(spacing: 4) {
                                appearance("system", "Système", "iphone")
                                appearance("light", "Clair", "sun.max")
                                appearance("dark", "Sombre", "moon")
                            }.padding(4).background(p.chip, in: Capsule())
                        }
                        section("Bibliothèque") {
                            Toggle(isOn: $settings.covers) {
                                VStack(alignment: .leading, spacing: 3) { Text("Afficher les couvertures").font(p.font(16)); Text("Vignette à gauche de chaque manga").font(p.font(13)).foregroundStyle(p.muted) }
                            }.themeCard().accessibilityIdentifier("showLibraryCovers")
                        }
                        section("Connexion") {
                            NavigationLink { ConnectionView(remote: remote, library: library) } label: {
                                HStack { VStack(alignment: .leading, spacing: 4) { Text("Connexion au Mac"); Text(remote.connection == nil ? "Non configurée" : remote.connected ? "Connecté" : "Mac injoignable").font(p.font(13)).foregroundStyle(p.muted) }; Spacer(); Image(systemName: "chevron.right").font(.caption) }.contentShape(Rectangle())
                            }.buttonStyle(.plain).themeCard().accessibilityIdentifier("macConnection")
                        }
                        section("Stockage") {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack { Text("\(StorageUsage.formatted(usage.total)) utilisés").font(p.font(16, title: true)); Spacer(); Text("sur l’appareil").font(p.font(13)).foregroundStyle(p.muted) }
                                GeometryReader { geometry in
                                    HStack(spacing: 2) {
                                        ForEach(Array([(usage.chapters, p.accent), (usage.covers, p.muted), (usage.cache, p.dotOff)].enumerated()), id: \.offset) { _, item in
                                            Rectangle().fill(item.1).frame(width: max(0, geometry.size.width - 4) * Double(item.0) / Double(max(1, usage.total)))
                                        }
                                    }
                                }.frame(height: 8).background(p.chip).clipShape(Capsule()).accessibilityHidden(true)
                                storageRow("Chapitres téléchargés", bytes: usage.chapters, color: p.accent)
                                storageRow("Couvertures", bytes: usage.covers, color: p.muted)
                                storageRow("Cache", bytes: usage.cache, color: p.dotOff)
                                Divider().overlay(p.line)
                                Button("Vider le cache") { clearCache() }.disabled(measuring)
                                Divider().overlay(p.line)
                                Button("Supprimer les chapitres lus", role: .destructive) { deleting = true }
                                    .foregroundStyle(p.danger).disabled(readCount == 0 || library.isBusy)
                                    .accessibilityIdentifier("deleteReadChapters")
                            }.themeCard()
                        }
                        section("À propos") {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack { Text("Version"); Spacer(); Text(version).foregroundStyle(p.muted) }
                                Divider().overlay(p.line)
                                NavigationLink("Notes de version") { ReleaseNotesView() }
                                Divider().overlay(p.line)
                                NavigationLink("Licences open source") { LicensesView() }
                                Divider().overlay(p.line)
                                Link("Contact et support", destination: URL(string: "https://github.com/YannickHerrero/MangaFlow/issues")!)
                            }.themeCard().foregroundStyle(p.ink)
                        }
                        if let message = error ?? library.error { Text(message).font(p.font(13)).foregroundStyle(p.danger) }
                    }.padding(.horizontal, 16).padding(.bottom, 34).frame(maxWidth: 700).frame(maxWidth: .infinity)
                }
            }.background(p.paper).toolbar(.hidden, for: .navigationBar)
                .task { await measure() }
                .confirmationDialog("Supprimer \(readCount) chapitre(s) lu(s) de cet appareil ?", isPresented: $deleting, titleVisibility: .visible) {
                    Button("Supprimer de cet appareil", role: .destructive) { library.error = nil; library.removeReadChapters(); Task { await measure() } }
                } message: { Text("L’historique de lecture, les mangas et leurs couvertures sont conservés. Aucun fichier du Mac ne sera supprimé.") }
        }
    }
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(p.font(14)).foregroundStyle(p.muted).padding(.horizontal, 8); content() }
    }
    private func appearance(_ value: String, _ label: String, _ symbol: String) -> some View {
        Button { settings.appearance = value } label: {
            HStack(spacing: 6) { Image(systemName: symbol); Text(label) }.font(p.font(14, title: settings.appearance == value))
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(settings.appearance == value ? p.ink : p.muted)
                .background(settings.appearance == value ? p.surface : .clear, in: Capsule()).contentShape(Capsule())
        }.buttonStyle(.plain).accessibilityIdentifier("appearance-\(value)").accessibilityAddTraits(settings.appearance == value ? .isSelected : [])
    }
    private func storageRow(_ title: String, bytes: Int64, color: Color) -> some View {
        HStack { RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10); Text(title).font(p.font(14)); Spacer(); Text(StorageUsage.formatted(bytes)).font(p.font(14)).foregroundStyle(p.muted) }
    }
    private var version: String { "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))" }
    private func measure() async {
        measuring = true; defer { measuring = false }
        let root = library.store.root, metadataRoot = metadata.root
        usage = await Task.detached(priority: .utility) { StorageUsage.measure(library: root, metadata: metadataRoot) }.value
    }
    private func clearCache() {
        do {
            try metadata.clearCoverCache()
            if FileManager.default.fileExists(atPath: StorageUsage.cacheRoot.path) { try FileManager.default.removeItem(at: StorageUsage.cacheRoot) }
            Task { await CropLoader.shared.clear(); await measure() }
        } catch { self.error = error.localizedDescription }
    }
}
struct ReleaseNotesView: View {
    @Environment(\.palette) private var p
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("Une bibliothèque plus simple").font(p.font(24, title: true))
            Text("Une interface unique en clair et sombre, avec des couvertures facultatives et deux onglets : Bibliothèque et Explorer.")
            Text("La progression reste conservée quand les chapitres lus sont supprimés de cet appareil. La connexion au Mac se trouve dans Réglages.")
            Text("Lecture originale ou recadrée, zoom sur les bulles, textes et cases, tri et filtres des chapitres : toutes tes fonctions de lecture restent disponibles.")
        }.padding(24) }.background(p.paper).themedNavigation("Notes de version")
    }
}
struct LicensesView: View {
    @Environment(\.palette) private var p
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text("MangaFlow").font(p.font(22, title: true))
            Text("Application et modèles exportés avec Ultralytics : AGPL-3.0. Modèle de bulles ogkalu : fiche amont Apache-2.0 ; export Ultralytics AGPL-3.0. ZIPFoundation : MIT. Serveur HakuNeko : Unlicense. Métadonnées et couvertures facultatives : AniList.")
            Link("Licences et attributions complètes", destination: URL(string: "https://github.com/YannickHerrero/MangaFlow/blob/main/THIRD_PARTY_NOTICES.md")!)
            Link("Code source", destination: URL(string: "https://github.com/YannickHerrero/MangaFlow")!)
        }.padding(24) }.background(p.paper).themedNavigation("Licences open source")
    }
}
