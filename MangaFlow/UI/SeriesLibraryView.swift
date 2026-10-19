import SwiftUI
import UniformTypeIdentifiers

struct SeriesLibraryView: View {
  @Bindable var library: LibraryModel
  let remote: RemoteModel
  @Environment(\.palette) private var p
  @State private var importer = false
  @State private var search = ""
  @State private var unread = false
  @State private var sort = "Ajout récent"
  private var displayed: [LibrarySeries] {
    library.series.filter {
      (!unread || $0.unread > 0)
        && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search))
    }.sorted {
      sort == "Titre"
        ? DocumentStore.naturalOrder($0.title, $1.title)
        : sort == "Lecture récente" ? $0.lastRead > $1.lastRead : $0.added > $1.added
    }
  }
  private var latest: LibrarySeries? {
    library.series.filter { $0.lastRead > .distantPast }.max { $0.lastRead < $1.lastRead }
      ?? library.series.first
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: p.theme == .brutal ? 0 : 16) {
          ThemeHeader(
            title: p.theme == .brutal ? "Biblio / \(library.series.count)" : "Bibliothèque",
            importing: { importer = true }, remote: remote, library: library)
          if p.theme == .brutal {
            HStack(alignment: .bottom) {
              Text("LIRE.").font(p.font(82, title: true)).tracking(-5)
              Spacer()
              Text(
                "\(library.series.count) MANGAS\n\(library.documents.count) CHAPITRES\n\(library.documents.filter { $0.readComplete != true }.count) NON LUS"
              ).font(p.font(11)).multilineTextAlignment(.trailing)
            }.padding(14)
          }
          if let latest, let doc = latest.resume {
            hero(latest, doc)
          } else {
            VStack(alignment: .leading, spacing: 16) {
              Text(
                p.theme == .terminal
                  ? "aucun chapitre local" : "Le prochain chapitre\ncommence ici."
              ).font(p.font(36, title: true))
              Text("Importe un CBZ ou choisis un manga dans Explorer.")
              Button("Importer un manga") { importer = true }.buttonStyle(ThemeButtonStyle())
            }.padding(20)
          }
          if library.isBusy {
            VStack(alignment: .leading, spacing: 10) {
              ProgressView(
                library.status, value: Double(library.activeDocument?.processedCount ?? 0),
                total: Double(max(1, library.activeDocument?.pages.count ?? 1)))
              Button("Pause") { library.cancel() }.accessibilityIdentifier("pauseConversion")
              Text("Découpage sur cet appareil · garde l’app ouverte").font(p.font(11))
            }.themeCard()
          }
          HStack {
            Image(systemName: "magnifyingglass")
            TextField("Rechercher dans la bibliothèque", text: $search).accessibilityIdentifier(
              "librarySearch")
          }.padding(14)
          HStack {
            Button("Tout") { unread = false }.fontWeight(!unread ? .bold : .regular)
            Button("Non lus · \(library.documents.filter { $0.readComplete != true }.count)") {
              unread = true
            }.fontWeight(unread ? .bold : .regular)
            Spacer(minLength: 0)
            Menu {
              ForEach(["Ajout récent", "Lecture récente", "Titre"], id: \.self) { value in
                Button(value) { sort = value }
              }
            } label: {
              Image(systemName: "arrow.up.arrow.down")
            }.accessibilityLabel("Trier la bibliothèque")
          }.padding(12).background(p.surface)
          if p.theme == .terminal {
            Text("┌─ bibliothèque [\(displayed.count)]").foregroundStyle(p.accent)
            ForEach(Array(displayed.enumerated()), id: \.element.id) { i, series in
              NavigationLink {
                SeriesDetailView(seriesID: series.id, library: library, remote: remote)
              } label: {
                HStack(alignment: .top, spacing: 10) {
                  Text(String(format: "%02d", i + 1)).foregroundStyle(p.accent)
                  VStack(alignment: .leading, spacing: 4) {
                    Text(series.title).font(p.font(14, title: true))
                    Text(
                      "\(series.documents.count) ch · \(series.unread) non lus · \(series.sourceName)"
                    ).font(p.font(11)).foregroundStyle(p.muted)
                  }
                  Spacer(minLength: 0)
                  Text(">")
                }.frame(minHeight: 44).padding(.vertical, 6)
                  .overlay(alignment: .bottom) { Rectangle().fill(p.line).frame(height: 0.5) }
              }.buttonStyle(.plain).accessibilityIdentifier("series-\(series.id)")
            }
          } else if p.theme == .brutal {
            ForEach(Array(displayed.enumerated()), id: \.element.id) { i, series in
              NavigationLink {
                SeriesDetailView(seriesID: series.id, library: library, remote: remote)
              } label: {
                HStack(spacing: 12) {
                  Text(String(format: "%02d", i + 1)).font(p.font(22))
                  VStack(alignment: .leading, spacing: 5) {
                    Text(series.title.uppercased()).font(p.font(21, title: true))
                    Text(
                      "\(series.documents.count) CH. · \(series.unread) NON LUS · \(series.sourceName)"
                    ).font(p.font(10))
                  }
                  Spacer()
                  Text("\(Int(series.progress*100))%").font(p.font(13))
                  cover(series).frame(width: 46, height: 64).border(p.ink, width: 3)
                }.padding(14).overlay(alignment: .bottom) {
                  Rectangle().fill(p.ink).frame(height: 3)
                }
              }.buttonStyle(.plain)
            }
          } else if p.theme == .manga {
            ForEach(Array(stride(from: 0, to: displayed.count, by: 2)), id: \.self) { start in
              GeometryReader { geometry in
                let asymmetric = start % 4 == 2
                let left = (geometry.size.width - 10) * (asymmetric ? 2.0 / 3.0 : 0.5)
                HStack(spacing: 10) {
                  NavigationLink {
                    SeriesDetailView(
                      seriesID: displayed[start].id, library: library, remote: remote)
                  } label: {
                    tile(displayed[start])
                  }.frame(width: left)
                  if displayed.indices.contains(start + 1) {
                    NavigationLink {
                      SeriesDetailView(
                        seriesID: displayed[start + 1].id, library: library, remote: remote)
                    } label: {
                      tile(displayed[start + 1])
                    }
                  }
                }.buttonStyle(.plain)
              }.frame(height: 196)
            }
          } else {
            LazyVGrid(
              columns: [GridItem(.adaptive(minimum: p.theme == .holo ? 160 : 155), spacing: 10)],
              spacing: 10
            ) {
              ForEach(displayed) { series in
                NavigationLink {
                  SeriesDetailView(seriesID: series.id, library: library, remote: remote)
                } label: {
                  tile(series)
                }.buttonStyle(.plain).accessibilityIdentifier("series-\(series.id)")
              }
            }
          }
          if displayed.isEmpty && !library.documents.isEmpty {
            Text("Aucun manga pour ce filtre.").padding(20)
          }
        }.padding(.horizontal, p.theme == .brutal ? 0 : p.theme == .manga ? 12 : 18).padding(
          .bottom, 24
        ).frame(maxWidth: 850)
          .frame(maxWidth: .infinity)
      }.background { ThemeBackground() }.toolbar(.hidden, for: .navigationBar)
        .fileImporter(
          isPresented: $importer,
          allowedContentTypes: [UTType(filenameExtension: "cbz") ?? .zip, .zip]
        ) { result in
          do {
            let url = try result.get()
            library.importCBZ(url)
          } catch { library.error = error.localizedDescription }
        }
        .alert(
          "Impossible de continuer",
          isPresented: Binding(
            get: { library.error != nil }, set: { if !$0 { library.error = nil } })
        ) {
          Button("Fermer") { library.error = nil }
        } message: {
          Text(library.error ?? "")
        }
    }
  }
  private func cover(_ series: LibrarySeries) -> some View {
    SeriesCover(
      key: series.id, title: series.title,
      fallback: series.documents.first.flatMap { doc in
        doc.pages.first.map { library.store.pageURL(doc, $0) }
      })
  }
  @ViewBuilder private func hero(_ series: LibrarySeries, _ doc: MangaDocument) -> some View {
    if p.theme == .terminal {
      VStack(alignment: .leading, spacing: 10) {
        Text("┌─ reprendre").foregroundStyle(p.accent)
        Text(series.title).font(p.font(16, title: true))
        Text("ch. \(doc.displayChapterTitle) · \(Int(doc.readingProgress * 100)) %")
          .foregroundStyle(p.muted)
        Button("[ lire → ]") { library.open(doc) }.buttonStyle(ThemeButtonStyle())
          .disabled(library.isBusy).accessibilityIdentifier("read-\(doc.title)")
      }.frame(maxWidth: .infinity, alignment: .leading).themeCard()
    } else if p.theme == .holo {
      VStack(alignment: .leading, spacing: 0) {
        Text("Ce soir, on lit").font(p.font(40, title: true))
        Text(series.title + " ?").font(p.font(40, title: true)).foregroundStyle(p.gradient)
      }.tracking(-1.6)
      ZStack {
        ForEach(Array(library.series.prefix(3).enumerated()), id: \.element.id) { i, item in
          cover(item).frame(width: i == 0 ? 172 : 140, height: i == 0 ? 252 : 206).clipShape(
            RoundedRectangle(cornerRadius: 22)
          )
          .rotationEffect(.degrees(i == 1 ? -10 : i == 2 ? 10 : 0)).offset(
            x: i == 1 ? -95 : i == 2 ? 95 : 0, y: i == 0 ? 0 : 12
          ).zIndex(i == 0 ? 3 : 1)
          .shadow(color: .purple.opacity(0.3), radius: 15, y: 14)
        }
      }.frame(maxWidth: .infinity).frame(height: 270)
      HStack {
        VStack(alignment: .leading, spacing: 8) {
          Text(doc.displayChapterTitle).lineLimit(1)
          ProgressView(value: doc.readingProgress)
        }
        Button("Reprendre") { library.open(doc) }.buttonStyle(ThemeButtonStyle()).disabled(
          library.isBusy
        ).accessibilityIdentifier("read-\(doc.title)")
      }.themeCard()
    } else if p.theme == .brutal {
      Button {
        library.open(doc)
      } label: {
        HStack {
          VStack(alignment: .leading, spacing: 10) {
            Text("→ REPRENDRE").font(p.font(12))
            Text(series.title.uppercased()).font(p.font(38, title: true))
            Text("\(doc.displayChapterTitle) · \(Int(doc.readingProgress*100))%").font(p.font(12))
          }
          Spacer()
          cover(series).frame(width: 78, height: 114).border(.black, width: 3)
        }.padding(14).foregroundStyle(.black).frame(maxWidth: .infinity).background(p.accent)
      }.buttonStyle(.plain).disabled(library.isBusy).accessibilityIdentifier("read-\(doc.title)")
    } else {
      Button {
        library.open(doc)
      } label: {
        ZStack(alignment: .bottomLeading) {
          MangaRays().stroke(p.ink.opacity(0.65), lineWidth: 1).background(p.surface)
          cover(series).frame(width: 138, height: 202).border(p.ink, width: 3).rotationEffect(
            .degrees(5)
          ).shadow(color: p.ink, radius: 0, x: 6, y: 6).frame(
            maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing
          ).padding(20)
          Text("On reprend\n\(doc.origin?.chapterTitle ?? "la lecture") ?!").font(p.font(15))
            .fontWeight(.black).multilineTextAlignment(.center).padding(16).background(
              p.paper, in: Ellipse()
            ).overlay(Ellipse().stroke(p.ink, lineWidth: 3)).frame(maxWidth: 190).frame(
              maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading
            ).padding(16)
          HStack(alignment: .bottom) {
            VStack(alignment: .leading) {
              Text(series.title.uppercased()).font(p.font(46, title: true)).padding(4).background(
                p.surface)
              Text("\(Int(doc.readingProgress*100)) %").padding(4).background(p.ink)
                .foregroundStyle(p.paper)
            }
            Spacer()
            Text("LIRE !").font(p.font(22, title: true)).padding(12).background(p.accent)
              .foregroundStyle(.white).rotationEffect(.degrees(-4))
          }.padding(16).padding(.bottom, 15)
        }.frame(height: 300).clipShape(MangaHeroShape()).overlay(
          MangaHeroShape().stroke(p.ink, lineWidth: 3))
      }.buttonStyle(.plain).disabled(library.isBusy).accessibilityIdentifier("read-\(doc.title)")
    }
  }
  @ViewBuilder private func tile(_ series: LibrarySeries) -> some View {
    if p.theme == .holo {
      HStack(spacing: 10) {
        cover(series).frame(width: 42, height: 60).clipShape(RoundedRectangle(cornerRadius: 10))
        VStack(alignment: .leading, spacing: 4) {
          Text(series.title).font(p.font(15, title: true)).lineLimit(1)
          Text("\(Int(series.progress*100)) % · \(series.unread) à lire").font(p.font(11))
        }
      }.frame(maxWidth: .infinity, alignment: .leading).themeCard()
    } else {
      ZStack(alignment: .bottomLeading) {
        cover(series)
        MangaDots().fill(p.ink.opacity(0.18))
        LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        VStack(alignment: .leading, spacing: 6) {
          Text(series.title.uppercased()).font(p.font(26, title: true)).padding(4).background(
            p.paper)
          Text("\(series.documents.count) ch. · \(series.unread) à lire").font(p.font(12)).padding(
            3
          ).background(p.paper)
        }.padding(10)
        Text(series.unread == 0 ? "完\n読" : "続\nき").font(p.font(13)).fontWeight(.black).padding(6)
          .background(p.accent).foregroundStyle(.white).border(p.ink, width: 2).frame(
            maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading
          ).padding(10)
      }.frame(height: 196).clipped().border(p.ink, width: 3)
    }
  }
}
struct MangaRays: Shape {
  func path(in rect: CGRect) -> Path {
    Path { p in
      let center = CGPoint(x: rect.width * 0.62, y: rect.height * 0.52)
      for i in 0..<52 {
        let a = Double(i) * Double.pi / 26
        p.move(to: center)
        p.addLine(to: CGPoint(x: center.x + cos(a) * 1000, y: center.y + sin(a) * 1000))
      }
    }
  }
}
struct SeriesDetailView: View {
  let seriesID: String
  @Bindable var library: LibraryModel
  let remote: RemoteModel
  @Environment(\.palette) private var p
  @State private var metadata = false
  @State private var edit: MangaDocument?
  @State private var removal: MangaDocument?
  private var series: LibrarySeries? { library.series.first { $0.id == seriesID } }
  var body: some View {
    ScrollView {
      if let series {
        VStack(alignment: .leading, spacing: 16) {
          if p.theme != .terminal {
            SeriesCover(
              key: series.id, title: series.title,
              fallback: series.documents.first.flatMap { d in
                d.pages.first.map { library.store.pageURL(d, $0) }
              }
            ).frame(height: 260).clipped()
          }
          Text(series.title).font(p.font(32, title: true))
          if p.theme == .terminal {
            Button("[ métadonnées / couverture ]") { metadata = true }.foregroundStyle(p.accent)
          }
          Text("\(series.sourceName) · \(series.documents.count) chapitres sur cet appareil")
          if let origin = series.documents.first?.origin,
            remote.connection?.serverID == origin.serverID
          {
            NavigationLink("Chapitres de la source") {
              MangaChaptersView(
                remote: remote,
                manga: RemoteManga(
                  id: origin.mangaID, sourceID: origin.sourceID, title: origin.mangaTitle),
                library: library)
            }
          }
          ForEach(series.chaptersNewestFirst) { doc in
            HStack {
              VStack(alignment: .leading, spacing: 6) {
                Text(doc.displayChapterTitle).font(p.font(17, title: true))
                Text(
                  doc.readComplete == true
                    ? "Lu" : "\(Int(doc.readingProgress*100)) % · \(doc.pages.count) pages"
                ).font(p.font(12))
                Button(
                  doc.complete
                    ? (doc.lastPanelID == nil ? "Lire" : "Continuer") : "Reprendre la conversion"
                ) { library.open(doc) }.disabled(library.isBusy).accessibilityIdentifier(
                  "read-\(doc.title)")
              }
              Spacer()
              Menu {
                Button(doc.readComplete == true ? "Marquer non lu" : "Marquer lu") {
                  library.edit(doc) {
                    $0.readComplete = doc.readComplete != true
                    if $0.readComplete == false { $0.lastPanelID = nil }
                  }
                }
                Button("Modifier le classement") { edit = doc }
                Button("Supprimer", role: .destructive) { removal = doc }
              } label: {
                Image(systemName: "ellipsis").padding(12)
              }
            }.themeCard()
          }
        }.padding(18).frame(maxWidth: 800).frame(maxWidth: .infinity)
      }
    }.background { ThemeBackground() }.navigationTitle(series?.title ?? "Manga")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { Button("Couverture", systemImage: "photo") { metadata = true } }
      .modifier(TerminalNavigation(title: series?.title ?? "Manga"))
      .sheet(isPresented: $metadata) { MetadataPicker(key: seriesID, title: series?.title ?? "") }
      .sheet(item: $edit) { doc in ChapterEditor(document: doc, library: library) }
      .confirmationDialog(
        "Supprimer ce chapitre et ses fichiers locaux ?",
        isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }),
        titleVisibility: .visible
      ) {
        Button("Supprimer", role: .destructive) {
          if let removal { library.remove(removal) }
          removal = nil
        }
      }
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

struct MangaHeroShape: Shape {
  func path(in r: CGRect) -> Path {
    Path { p in
      p.move(to: .zero)
      p.addLine(to: CGPoint(x: r.maxX, y: 0))
      p.addLine(to: CGPoint(x: r.maxX, y: r.maxY * 0.92))
      p.addLine(to: CGPoint(x: 0, y: r.maxY))
      p.closeSubpath()
    }
  }
}
struct MangaDots: Shape {
  func path(in rect: CGRect) -> Path {
    Path { p in
      for y in stride(from: CGFloat(0), to: rect.height, by: 7) {
        for x in stride(from: CGFloat(0), to: rect.width, by: 7) {
          p.addEllipse(in: CGRect(x: x, y: y, width: 2.2, height: 2.2))
        }
      }
    }
  }
}
