import SwiftUI

struct SettingsView: View {
  let remote: RemoteModel
  let library: LibraryModel
  @Environment(ThemeSettings.self) private var settings
  @Environment(MetadataStore.self) private var metadata
  @Environment(\.palette) private var p
  @Environment(\.dismiss) private var dismiss
  @State private var storage: Int64 = 0
  @State private var error: String?
  var body: some View {
    @Bindable var settings = settings
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          HStack {
            Text("Réglages").font(p.font(24, title: true))
            Spacer()
            Button("OK") { dismiss() }.buttonStyle(.plain)
          }
          Text("Thème").font(p.font(22, title: true))
          ForEach(AppTheme.allCases) { theme in
            Button {
              settings.theme = theme
            } label: {
              HStack(spacing: 14) {
                ThemePreview(theme: theme).frame(width: 76, height: 72)
                VStack(alignment: .leading, spacing: 5) {
                  Text(theme.name).font(p.font(17, title: true))
                  Text(theme.detail).font(p.font(12))
                }
                Spacer()
                Image(systemName: settings.theme == theme ? "checkmark.circle.fill" : "circle")
              }.themeCard()
            }.buttonStyle(.plain).accessibilityIdentifier("theme-\(theme.rawValue)")
              .accessibilityValue(settings.theme == theme ? "Sélectionné" : "")
          }
          Text("Apparence").font(p.font(22, title: true))
          HStack {
            ForEach([("system", "Système"), ("light", "Clair"), ("dark", "Sombre")], id: \.0) {
              mode in
              Button {
                settings.appearance = mode.0
              } label: {
                Text(mode.1).frame(maxWidth: .infinity).padding(12).background(
                  settings.appearance == mode.0 ? p.accent : p.surface
                ).foregroundStyle(settings.appearance == mode.0 ? Color.white : p.ink)
              }.buttonStyle(.plain).accessibilityIdentifier("appearance-\(mode.0)")
            }
          }
          Text("Général").font(p.font(22, title: true))
          NavigationLink {
            ConnectionView(remote: remote, library: library)
          } label: {
            HStack {
              Text(remote.connection?.serverURL.host ?? "Connecter le Mac")
              Spacer()
              Text(remote.connected ? "Connecté" : "Déconnecté").font(p.font(11))
            }.themeCard()
          }
          HStack {
            Text("Stockage local")
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: storage, countStyle: .file))
          }.themeCard()
          Text(
            "Pages importées et couvertures en cache. Effacer le cache conserve les mangas et leurs associations AniList."
          ).font(p.font(12))
          Button("Vider le cache des couvertures") {
            do {
              try metadata.clearCoverCache()
              measure()
            } catch { self.error = error.localizedDescription }
          }
          Text("À propos").font(p.font(22, title: true))
          Text(
            "MangaFlow \(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? ""))"
          )
          Text(
            "Lecture hors ligne · Découpage sur cet appareil\nSources HakuNeko exécutées sur ton Mac"
          ).font(p.font(12))
          Link(
            "Métadonnées et couvertures : AniList", destination: URL(string: "https://anilist.co")!)
          Link(
            "Code source et licences",
            destination: URL(string: "https://github.com/YannickHerrero/MangaFlow")!)
          Text(
            "Polices : Space Grotesk, Archivo Black, Space Mono, Anton et Zen Kaku Gothic New — SIL OFL. MangaFlow et son modèle : AGPL-3.0. ZIPFoundation : MIT."
          ).font(p.font(11))
          if let error { Text(error).foregroundStyle(.orange) }
        }.padding(20).frame(maxWidth: 700).frame(maxWidth: .infinity)
      }.background { ThemeBackground() }.toolbar(.hidden, for: .navigationBar).task { measure() }
    }
  }
  private func measure() {
    let roots = [library.store.root, metadata.root]
    storage = roots.reduce(Int64(0)) { sum, root in
      let files = FileManager.default.enumerator(
        at: root, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey])
      var count: Int64 = 0
      while let url = files?.nextObject() as? URL {
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
          values.isRegularFile == true
        {
          count += Int64(values.fileSize ?? 0)
        }
      }
      return sum + count
    }
  }
}
struct ThemePreview: View {
  let theme: AppTheme
  var body: some View {
    let p = ThemePalette(theme: theme, dark: false)
    ZStack {
      p.paper
      if theme == .holo { p.gradient.opacity(0.25) }
      if theme == .manga { MangaRays().stroke(p.ink.opacity(0.5), lineWidth: 0.5) }
      VStack(spacing: 6) {
        Text("Aa").font(p.font(27, title: true))
        Rectangle().fill(p.accent).frame(height: 8)
      }
    }.clipped().overlay(Rectangle().stroke(p.ink, lineWidth: theme == .holo ? 0 : 2))
  }
}
