import Foundation

/// Chapter numbers are not connector indices: indices can change or run newest-first.
enum ChapterListFilter {
    private static let patterns: [NSRegularExpression] = [
        #"(?i)\b(?:chapitre|chapter|chap|ch|scan|épisode|episode)\.?\s*(?:n[°o]\s*)?#?\s*(\d+(?:[.,]\d+)?)"#,
        #"^\s*[-–—:#]*\s*(\d+(?:[.,]\d+)?)(?=\s|$|[-–—:])"#
    ].compactMap { try? NSRegularExpression(pattern: $0) }

    static func number(in title: String, mangaTitle: String) -> Decimal? {
        var value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !mangaTitle.isEmpty, let prefix = value.range(of: mangaTitle, options: [.anchored, .caseInsensitive]) {
            value.removeSubrange(prefix)
        }
        for regex in patterns {
            guard let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
                  let range = Range(match.range(at: 1), in: value) else { continue }
            return Decimal(string: String(value[range]).replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
        }
        return nil
    }

    static func local(_ series: LibrarySeries, ascending: Bool, hideRead: Bool) -> [MangaDocument] {
        let newest = series.chaptersNewestFirst
        let ordered = ascending ? Array(newest.reversed()) : newest
        return hideRead ? ordered.filter { $0.readComplete != true } : ordered
    }

    static func readBoundary(documents: [MangaDocument], serverID: String?, manga: RemoteManga,
                             chapters: [RemoteChapter]) -> Decimal? {
        guard let serverID else { return nil }
        // Resolve by opaque chapter ID, even if its local display title was edited.
        let titles = Dictionary(chapters.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
        return documents.compactMap { doc -> Decimal? in
            guard doc.readComplete == true, let origin = doc.origin,
                  origin.serverID == serverID, origin.sourceID == manga.sourceID, origin.mangaID == manga.id else { return nil }
            if let title = titles[origin.chapterID], let current = number(in: title, mangaTitle: manga.title) {
                return current
            }
            return number(in: origin.chapterTitle, mangaTitle: origin.mangaTitle)
        }.max()
    }

    static func remote(_ chapters: [RemoteChapter], boundary: Decimal?, mangaTitle: String) -> [RemoteChapter] {
        guard let boundary else { return chapters }
        return chapters.filter { chapter in
            // Unknown/special chapters stay visible. Never guess using a connector's index.
            guard let number = number(in: chapter.title, mangaTitle: mangaTitle) else { return true }
            return number >= boundary
        }
    }
}
