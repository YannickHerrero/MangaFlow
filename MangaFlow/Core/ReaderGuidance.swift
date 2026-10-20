import Foundation

/// Shared by page rows and the fixed reader control; never tied to a row's lifetime.
struct ReaderFocus: Equatable {
    let pageID: Int
    let targetID: String
}

enum ReaderGuidance {
    enum Step: Equatable {
        case focus(ReaderFocus)
        case page(Int)
        case overview
    }

    static func next(pages: [MangaPage], pageID: Int, focus: ReaderFocus?) -> Step {
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return .overview }
        let page = pages[index]
        let texts = PanelZoom.orderedText(page.textRegions ?? [], panels: page.zoomPanels ?? page.panels, rtl: true)
        let focusedIndex = focus.flatMap { focused in
            focused.pageID == pageID ? texts.firstIndex { $0.id == focused.targetID } : nil
        }
        let nextIndex = focusedIndex.map { $0 + 1 } ?? 0
        if nextIndex < texts.count {
            return .focus(.init(pageID: pageID, targetID: texts[nextIndex].id))
        }
        if index + 1 < pages.count { return .page(pages[index + 1].id) }
        return .overview
    }
}
