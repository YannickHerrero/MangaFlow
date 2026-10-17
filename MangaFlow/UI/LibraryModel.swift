import SwiftUI

@Observable @MainActor
final class LibraryModel {
    var documents: [MangaDocument] = []
    var selected: UUID?
    var error: String?
    var isBusy = false
    var status = ""
    var activeDocument: MangaDocument?
    private var work: Task<Void, Never>?
    private var importer: Task<MangaDocument, Error>?
    let store = DocumentStore()
    @ObservationIgnored private lazy var engine = ConversionEngine(store: store)

    init() {
        do { documents = try store.loadAll() }
        catch { self.error = error.localizedDescription }
    }
    func update(_ doc: MangaDocument) {
        if let index = documents.firstIndex(where: { $0.id == doc.id }) { documents[index] = doc }
        else { documents.insert(doc, at: 0) }
    }
    @discardableResult
    func importCBZ(_ url: URL, remoteArtifactID: String? = nil) -> Task<Void, Never>? {
        guard !isBusy else { return nil }
        isBusy = true; status = "Ouverture du CBZ…"; activeDocument = nil
        let store = store
        let importTask = Task.detached(priority: .userInitiated) { try store.importArchive(url) }
        importer = importTask
        work = Task {
            defer { isBusy = false; activeDocument = nil; importer = nil; UIApplication.shared.isIdleTimerDisabled = false }
            UIApplication.shared.isIdleTimerDisabled = true
            do {
                var doc = try await importTask.value
                doc.remoteArtifactID = remoteArtifactID
                try store.save(doc)
                update(doc)
                try Task.checkCancellation()
                activeDocument = doc
                let converted = try await engine.convert(doc) { [self] doc in
                    await self.conversionProgress(doc)
                }
                update(converted); selected = converted.id
                exportDiagnostics(converted)
            } catch is CancellationError {
                status = "Conversion mise en pause"
            } catch { self.error = error.localizedDescription }
        }
        return work
    }
    func resume(_ document: MangaDocument) {
        guard !isBusy else { return }
        isBusy = true; activeDocument = document; status = "Préparation du détecteur…"
        work = Task {
            UIApplication.shared.isIdleTimerDisabled = true
            defer { isBusy = false; activeDocument = nil; UIApplication.shared.isIdleTimerDisabled = false }
            do {
                let converted = try await engine.convert(document) { [self] doc in
                    await self.conversionProgress(doc)
                }
                update(converted); selected = converted.id
                exportDiagnostics(converted)
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
    func importRemoteCBZ(_ url: URL, artifactID: String) async throws {
        guard !isBusy else { throw RemoteFailure(code: "library_busy", message: "Termine ou mets en pause la conversion en cours avant d’importer un chapitre.") }
        if let existing = documents.first(where: { $0.remoteArtifactID == artifactID }) {
            if existing.complete { selected = existing.id } else { resume(existing) }
            return
        }
        error = nil
        await importCBZ(url, remoteArtifactID: artifactID)?.value
        if let error { throw RemoteFailure(code: "import_failed", message: error) }
    }
    func conversionProgress(_ doc: MangaDocument) {
        update(doc); activeDocument = doc
        status = "Page \(doc.processedCount) sur \(doc.pages.count)"
    }
    func cancel() { importer?.cancel(); work?.cancel() }
    func remove(_ doc: MangaDocument) {
        guard !isBusy else { return }
        do { try store.remove(doc); documents.removeAll { $0.id == doc.id } }
        catch { self.error = error.localizedDescription }
    }
    func remember(documentID: UUID, panelID: String) {
        guard let index = documents.firstIndex(where: { $0.id == documentID }) else { return }
        documents[index].lastPanelID = panelID
        try? store.save(documents[index])
    }
    private func exportDiagnostics(_ document: MangaDocument) {
        #if DEBUG
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let data = try? JSONEncoder().encode(document) {
            try? data.write(to: folder.appendingPathComponent("last-conversion.json"), options: .atomic)
        }
        #endif
    }
}
