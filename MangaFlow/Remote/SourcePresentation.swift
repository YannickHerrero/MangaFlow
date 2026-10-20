import SwiftUI

enum SourceFavorites {
    static func keys(_ value: String) -> [String] { (try? JSONDecoder().decode([String].self, from: Data(value.utf8))) ?? [] }
    static func key(server: String?, source: String) -> String { ChapterOrigin.key(server ?? "", source, "") }
    static func contains(_ value: String, server: String?, source: String) -> Bool { keys(value).contains(key(server: server, source: source)) }
    static func toggled(_ value: String, server: String?, source: String) -> String {
        var items = keys(value); let id = key(server: server, source: source)
        if let index = items.firstIndex(of: id) { items.remove(at: index) } else { items.append(id) }
        return String(decoding: (try? JSONEncoder().encode(items)) ?? Data("[]".utf8), as: UTF8.self)
    }
    static func followedLabel(_ count: Int) -> String { count == 1 ? "1 manga suivi" : "\(count) mangas suivis" }
    static func languages(_ codes: [String]) -> String {
        let names = ["fr": "Français", "en": "Anglais", "ja": "Japonais", "es": "Espagnol", "multi": "Multilingue"]
        return codes.map { names[$0] ?? Locale(identifier: "fr").localizedString(forLanguageCode: $0) ?? $0 }.joined(separator: " · ")
    }
}
struct MangaLibraryIndex {
    let documents: [MangaDocument]
    @MainActor init(library: LibraryModel, server: String?, manga: RemoteManga) {
        documents = library.documents.filter { $0.hasLocalFiles && $0.complete && $0.origin?.serverID == server && $0.origin?.sourceID == manga.sourceID && $0.origin?.mangaID == manga.id }
    }
    var chapterIDs: Set<String> { Set(documents.compactMap { $0.origin?.chapterID }) }
    var unread: Bool { documents.contains { $0.readComplete != true } }
}
struct ListDot: View {
    let active: Bool
    @Environment(\.palette) private var p
    var body: some View { Circle().fill(active ? p.accent : p.dotOff).frame(width: 7, height: 7).padding(.top, 8).accessibilityHidden(true) }
}
struct FavoriteStar: View {
    let saved: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: saved ? "star.fill" : "star").font(.system(size: 18)).foregroundStyle(saved ? Color(hex: 0xCA8A04) : Color.gray).frame(width: 44, height: 44).contentShape(Rectangle()) }
            .buttonStyle(.plain).accessibilityLabel(saved ? "Retirer des favoris" : "Ajouter aux favoris")
    }
}
struct RoundBackButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { RoundIconButton(symbol: "chevron.left", label: "Retour") { dismiss() }.accessibilityIdentifier("routeBack") }
}
struct SourceSearchField: View {
    let placeholder: String
    @Binding var text: String
    @Environment(\.palette) private var p
    @FocusState private var focused: Bool
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(p.muted)
            TextField(placeholder, text: $text).font(p.font(15)).focused($focused).submitLabel(.search).onSubmit { focused = false }
        }.padding(.horizontal, 16).frame(minHeight: 44).background(p.surface, in: Capsule()).overlay(Capsule().stroke(p.line, lineWidth: 1))
    }
}
struct SourcePageStyle: ViewModifier {
    @Environment(\.palette) private var p
    func body(content: Content) -> some View {
        content.background(p.paper).toolbar(.hidden, for: .navigationBar).preference(key: HideMainTabsKey.self, value: true).scrollDismissesKeyboard(.interactively)
    }
}
extension View { func sourcePage() -> some View { modifier(SourcePageStyle()) } }
