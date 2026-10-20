import SwiftUI
import UniformTypeIdentifiers

struct SeriesLibraryView: View {
    @Bindable var library: LibraryModel
    let remote: RemoteModel
    @Environment(\.palette) private var p
    @State private var search = ""
    @State private var searching = false
    @State private var importer = false
    @State private var unreadOnly = false
    @State private var sort = "Titre"
    private var displayed: [LibrarySeries] {
        library.series.filter { (!unreadOnly || $0.unread > 0) && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)) }
            .sorted { sort == "Lecture récente" ? $0.lastRead > $1.lastRead : DocumentStore.naturalOrder($0.title, $1.title) }
    }
    private var ongoing: [LibrarySeries] { displayed.filter { $0.lastRead > .distantPast && $0.resume != nil && $0.unread > 0 } }
    private var groups: [(String, [LibrarySeries])] {
        let ids = Set(ongoing.map(\.id))
        return Dictionary(grouping: displayed.filter { !ids.contains($0.id) }, by: \.sourceName)
            .map { ($0.key, $0.value) }.sorted { DocumentStore.naturalOrder($0.0, $1.0) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ThemeHeader(title: "Bibliothèque", search: { searching.toggle() }, remote: remote, library: library)
                        .padding(.horizontal, 20).padding(.top, 8)
                    Text("Bibliothèque").font(p.font(26, title: true)).padding(.top, 18).padding(.horizontal, 24)
                    (Text("\(library.series.count) mangas · ").foregroundStyle(p.muted)
                     + Text("\(library.allDocuments.filter { $0.readComplete != true }.count) chapitres non lus").foregroundStyle(p.accent))
                        .font(p.font(14)).padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 22)
                    if searching {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundStyle(p.muted)
                            TextField("Rechercher dans la bibliothèque", text: $search).submitLabel(.search).accessibilityIdentifier("librarySearch")
                            Menu {
                                Toggle("Mangas avec des chapitres non lus", isOn: $unreadOnly)
                                Picker("Trier les mangas", selection: $sort) {
                                    Text("Titre").tag("Titre"); Text("Lecture récente").tag("Lecture récente")
                                }
                            } label: { Image(systemName: "line.3.horizontal.decrease") }
                                .accessibilityLabel("Filtrer la bibliothèque")
                        }.themeCard().padding(.horizontal, 24).padding(.bottom, 16)
                    }
                    if library.isBusy { ConversionStatus(library: library).padding(.horizontal, 24).padding(.bottom, 16) }
                    if !ongoing.isEmpty { section("En cours", books: ongoing) }
                    ForEach(groups, id: \.0) { title, books in section(title, books: books) }
                    if displayed.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(library.series.isEmpty ? "Ta bibliothèque commence ici." : "Aucun manga ne correspond à cette recherche.").font(p.font(18, title: true))
                            if library.series.isEmpty {
                                Text("Importe un CBZ ou choisis un manga dans Explorer.").foregroundStyle(p.muted)
                                Button("Importer un CBZ") { importer = true }.buttonStyle(ThemeButtonStyle()).accessibilityIdentifier("importCBZ")
                            }
                        }.padding(24)
                    }
                }.padding(.bottom, 20).frame(maxWidth: 800).frame(maxWidth: .infinity)
            }.background(p.paper).toolbar(.hidden, for: .navigationBar)
                .fileImporter(isPresented: $importer, allowedContentTypes: [.zip, UTType(filenameExtension: "cbz") ?? .zip]) { result in
                    do { library.importCBZ(try result.get()) } catch { library.error = error.localizedDescription }
                }

        }
    }
    private func section(_ title: String, books: [LibrarySeries]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(p.font(14)).foregroundStyle(p.muted).padding(.horizontal, 24)
            ForEach(books) { series in
                NavigationLink { SeriesDetailView(seriesID: series.id, library: library, remote: remote) } label: {
                    LibrarySeriesRow(series: series, library: library)
                }.buttonStyle(.plain).accessibilityIdentifier("series-\(series.id)")
            }
        }.padding(.bottom, 18)
    }
}
struct LibrarySeriesRow: View {
    let series: LibrarySeries
    let library: LibraryModel
    @Environment(ThemeSettings.self) private var settings
    @Environment(MetadataStore.self) private var metadata
    @Environment(\.palette) private var p
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle().fill(series.unread > 0 ? p.accent : p.dotOff).frame(width: 7, height: 7).padding(.top, settings.covers ? 28 : 7)
            if settings.covers {
                SeriesCover(key: series.id, title: series.title, fallback: fallback)
                    .frame(width: 44, height: 64).clipShape(RoundedRectangle(cornerRadius: 6)).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(series.title).font(p.font(16)).fontWeight(.medium).lineLimit(2)
                (Text(series.sourceName + " · " + series.readingSummary).foregroundStyle(p.muted)
                 + Text(series.unread > 0 ? " · \(series.unread) non lus" : "").foregroundStyle(p.accent))
                    .font(p.font(13)).lineLimit(3)
                if !series.documents.contains(where: \.hasLocalFiles) { Text("Aucun chapitre local").font(p.font(12)).foregroundStyle(p.muted) }
                if metadata.entries[series.id]?.media?.status == "FINISHED" { Text("Publication terminée").font(p.font(12)).foregroundStyle(p.muted) }
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 24).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            .task { await metadata.resolve(key: series.id, title: series.title) }
    }
    private var fallback: URL? {
        guard let doc = series.documents.first(where: \.hasLocalFiles), let page = doc.pages.first else { return nil }
        return library.store.pageURL(doc, page)
    }
}
extension LibrarySeries {
    var readingSummary: String {
        let numbers = documents.filter { $0.readComplete == true }.compactMap { ChapterListFilter.number(in: $0.displayChapterTitle, mangaTitle: title) }
        if let last = numbers.max() { return "Dernier lu : ch. \(NSDecimalNumber(decimal: last).stringValue)" }
        if !documents.isEmpty && documents.allSatisfy({ $0.readComplete == true }) { return "Chapitres lus" }
        return lastRead > .distantPast ? "Lecture en cours" : "Pas commencé"
    }
}
struct ConversionStatus: View {
    let library: LibraryModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(library.status, value: Double(library.activeDocument?.processedCount ?? 0), total: Double(max(1, library.activeDocument?.pages.count ?? 1)))
            HStack { Text("Préparation sur cet appareil").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Pause") { library.cancel() } }
        }.themeCard()
    }
}
struct SeriesDetailView: View {
    let seriesID: String
    @Bindable var library: LibraryModel
    let remote: RemoteModel
    @Environment(\.palette) private var p
    @Environment(ThemeSettings.self) private var settings
    @Environment(MetadataStore.self) private var metadata
    @AppStorage("libraryChaptersAscending") private var ascending = false
    @AppStorage("libraryHideReadChapters") private var hideRead = false
    @State private var showMetadata = false
    @State private var showSettings = false
    @State private var showSource = false
    @State private var pendingSettingsAction: SettingsAction?
    private enum SettingsAction { case cover, source }
    @State private var edit: MangaDocument?
    @State private var removal: MangaDocument?
    private var series: LibrarySeries? { library.series.first { $0.id == seriesID } }
    var body: some View {
        ScrollView {
            if let series {
                LazyVStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 16) {
                        if settings.covers { SeriesCover(key: series.id, title: series.title, fallback: fallback(series)).frame(width: 72, height: 104).clipShape(RoundedRectangle(cornerRadius: 8)) }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(series.title).font(p.font(26, title: true))
                            Text(series.sourceName).foregroundStyle(p.muted)
                            Text(series.readingSummary).font(p.font(13)).foregroundStyle(p.muted)
                            if let status = metadata.entries[series.id]?.media?.publicationLabel { Text(status).font(p.font(13)).foregroundStyle(p.green) }
                        }
                        Spacer(minLength: 0)
                        RoundIconButton(symbol: "gearshape", label: "Réglages du manga") { showSettings = true }
                            .accessibilityIdentifier("openMangaSettings")
                    }
                    let chapters = ChapterListFilter.local(series, ascending: ascending, hideRead: hideRead)
                    if chapters.isEmpty { Text("Aucun chapitre non lu à afficher.").foregroundStyle(p.muted) }
                    ForEach(chapters) { doc in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(doc.displayChapterTitle).font(p.font(16, title: true))
                                Text(doc.hasLocalFiles ? (doc.readComplete == true ? "Lu · sur cet appareil" : "\(Int(doc.readingProgress * 100)) % · \(doc.pages.count) pages") : (doc.readComplete == true ? "Lu · supprimé de cet appareil" : "Non lu · à télécharger"))
                                    .font(p.font(13)).foregroundStyle(p.muted)
                                if doc.hasLocalFiles {
                                    Button(doc.complete ? (doc.lastPanelID == nil ? "Lire" : "Continuer") : "Reprendre la préparation") { library.open(doc) }
                                        .disabled(library.isBusy).accessibilityIdentifier("read-\(doc.title)")
                                }
                            }
                            Spacer()
                            Menu {
                                Button(doc.readComplete == true ? "Marquer non lu" : "Marquer lu") { library.edit(doc) { $0.readComplete = doc.readComplete != true; if $0.readComplete == false { $0.lastPanelID = nil } } }
                                Button("Modifier le classement") { edit = doc }
                                if doc.hasLocalFiles { Button("Supprimer de cet appareil", role: .destructive) { removal = doc } }
                            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        }.themeCard()
                    }
                }.padding(24).frame(maxWidth: 800).frame(maxWidth: .infinity)
            }
        }.background(p.paper).themedNavigation(series?.title ?? "Manga")
            .sheet(isPresented: $showSettings, onDismiss: {
                let action = pendingSettingsAction; pendingSettingsAction = nil
                switch action { case .cover: showMetadata = true; case .source: showSource = true; case nil: break }
            }) {
                ThemeHost {
                    MangaSettingsSheet(ascending: $ascending, hideRead: $hideRead,
                        hasSource: series?.documents.contains(where: { $0.origin != nil }) == true,
                        sourceConnected: series?.documents.compactMap(\.origin).first.map { remote.connection?.serverID == $0.serverID } == true,
                        cover: { pendingSettingsAction = .cover; showSettings = false },
                        source: { pendingSettingsAction = .source; showSettings = false })
                }.presentationCornerRadius(30).presentationDragIndicator(.visible)
            }
            .navigationDestination(isPresented: $showSource) {
                if let origin = series?.documents.compactMap(\.origin).first {
                    MangaChaptersView(remote: remote, manga: RemoteManga(id: origin.mangaID, sourceID: origin.sourceID, title: origin.mangaTitle), library: library)
                }
            }
            .sheet(isPresented: $showMetadata) { ThemeHost { MetadataPicker(key: seriesID, title: series?.title ?? "") } }
            .sheet(item: $edit) { doc in ThemeHost { ChapterEditor(document: doc, library: library) } }
            .confirmationDialog("Supprimer ce chapitre de cet appareil ? La progression sera conservée. Aucun fichier du Mac ne sera supprimé.", isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }), titleVisibility: .visible) {
                Button("Supprimer de cet appareil", role: .destructive) { if let removal { library.remove(removal) }; removal = nil }
            }
    }
    private func fallback(_ series: LibrarySeries) -> URL? {
        guard let doc = series.documents.first(where: \.hasLocalFiles), let page = doc.pages.first else { return nil }
        return library.store.pageURL(doc, page)
    }
}
private struct MangaSettingsSheet: View {
    @Binding var ascending: Bool
    @Binding var hideRead: Bool
    let hasSource: Bool
    let sourceConnected: Bool
    let cover: () -> Void
    let source: () -> Void
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Réglages du manga").font(p.font(22, title: true))
                Spacer()
                RoundIconButton(symbol: "xmark", label: "Fermer les réglages du manga") { dismiss() }
            }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chapitres").font(p.font(14)).foregroundStyle(p.muted).padding(.horizontal, 8)
                        VStack(spacing: 16) {
                            Picker("Ordre des chapitres", selection: $ascending) { Text("Croissant").tag(true); Text("Décroissant").tag(false) }
                                .pickerStyle(.menu).accessibilityIdentifier("chapterSortOrder")
                            Divider().overlay(p.line)
                            Toggle("Masquer les chapitres lus", isOn: $hideRead).accessibilityIdentifier("libraryHideReadChapters")
                        }.themeCard()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Manga").font(p.font(14)).foregroundStyle(p.muted).padding(.horizontal, 8)
                        VStack(alignment: .leading, spacing: 16) {
                            Button(action: cover) { settingsRow("Modifier la couverture AniList") }
                                .accessibilityIdentifier("editMangaCover")
                            if hasSource {
                                Divider().overlay(p.line)
                                if sourceConnected {
                                    Button(action: source) { settingsRow("Chapitres de la source") }.accessibilityIdentifier("openMangaSource")
                                } else {
                                    Text("La connexion à la source se règle dans Réglages → Connexion au Mac.").font(p.font(13)).foregroundStyle(p.muted)
                                }
                            }
                        }.buttonStyle(.plain).themeCard()
                    }
                }.padding(.horizontal, 16).padding(.bottom, 34).frame(maxWidth: 700).frame(maxWidth: .infinity)
            }
        }.background(p.paper)
    }
    private func settingsRow(_ title: String) -> some View {
        HStack { Text(title).font(p.font(16)); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(p.muted) }.contentShape(Rectangle())
    }
}
struct ChapterEditor: View {
  let document: MangaDocument
  let library: LibraryModel
  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  @State private var order = ""
  @State private var selected = ""
  var body: some View {
    NavigationStack {
      Form {
        TextField("Titre du chapitre", text: $title)
        TextField("Ordre", text: $order).keyboardType(.decimalPad)
        if document.origin == nil {
          Picker("Série", selection: $selected) {
            Text("Document indépendant").tag("")
            ForEach(library.series) { s in Text(s.title + " · " + s.sourceName).tag(s.id) }
          }
          Text("Le rattachement conserve les fichiers et la progression.").font(.caption)
        } else {
          Text(
            "Série liée à \(document.origin!.sourceName). Le manga de la source reste son identité."
          )
        }
      }.navigationTitle("Classement").toolbar {
        Button("Enregistrer") {
          library.edit(document) { d in
            d.chapterTitleOverride = title
            d.chapterOrder = Double(order.replacingOccurrences(of: ",", with: "."))
            if d.origin == nil {
              if let target = library.series.first(where: { $0.id == selected }),
                let first = target.documents.first
              {
                // A local attachment adopts only grouping, never a false chapter provenance.
                let group = first.manualSeriesID ?? first.id
                for member in target.documents where member.origin == nil {
                  library.edit(member) {
                    $0.manualSeriesID = group
                    $0.manualSeriesTitle = target.title
                    $0.manualGroupKey = target.id
                  }
                }
                d.manualSeriesID = group
                d.manualSeriesTitle = target.title
                d.manualGroupKey = target.id
              } else {
                d.manualSeriesID = nil
                d.manualSeriesTitle = nil
                d.manualGroupKey = nil
              }
            }
          }
          dismiss()
        }
        Button("Annuler") { dismiss() }
      }
      .onAppear {
        title = document.displayChapterTitle
        order = String(document.chapterOrder ?? Double(document.origin?.order ?? 0))
        selected = document.seriesID
      }
    }
  }
}
