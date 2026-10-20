import SwiftUI

struct ChapterDownloadRow: View {
    @Bindable var remote: RemoteModel
    let library: LibraryModel
    let manga: RemoteManga
    let chapter: RemoteChapter
    @Environment(\.palette) private var p
    private var key: ChapterDownloadKey { ChapterDownloadKey(manga: manga, chapter: chapter) }
    private var job: RemoteJob? { remote.downloadJob(for: manga, chapter: chapter) }
    private var requesting: Bool { remote.requestingDownloads.contains(key) }
    private var active: Bool { job.map { !$0.finished } ?? false }
    private var completed: Bool { job?.state == "completed" && job?.artifactID != nil }
    private var failure: String? { remote.downloadErrors[key] ?? job?.error?.localizedDescription }
    private var pending: Bool { remote.batchEntries(for: manga).contains { $0.chapter.id == chapter.id } }
    private var local: MangaDocument? {
        if let job, let doc = remote.localDocument(for: job, library: library), doc.complete { return doc }
        return MangaLibraryIndex(library: library, server: remote.connection?.serverID, manga: manga).documents.first { $0.origin?.chapterID == chapter.id }
    }
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ListDot(active: local?.readComplete != true && local != nil)
            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.title).font(p.font(16)).fontWeight(.medium)
                if local != nil { Text("Dans la bibliothèque").font(p.font(13)).fontWeight(.medium).foregroundStyle(p.green) }
                else if pending { Text("Demande enregistrée · en attente d’envoi").font(p.font(13)).foregroundStyle(p.muted) }
                else if requesting { Text("Envoi de la demande…").font(p.font(13)).foregroundStyle(p.muted) }
                else if let language = chapter.language, !language.isEmpty { Text(SourceFavorites.languages([language])).font(p.font(13)).foregroundStyle(p.muted) }
                if active, let job {
                    Text(job.state == "queued" ? "En attente sur le Mac" : "Téléchargement sur le Mac…").font(p.font(13)).foregroundStyle(p.muted)
                    if job.progress.total > 0 { ProgressView(value: Double(job.progress.completed), total: Double(job.progress.total)).tint(p.accent) }
                    Button("Annuler") { Task { await remote.cancel(job) } }.font(p.font(12))
                }
                if completed, local == nil, let job {
                    if remote.transferJobID == job.id {
                        ProgressView(remote.transferPhase).font(p.font(12))
                        Button("Annuler le transfert") { remote.cancelTransfer(library: library) }.font(p.font(12))
                    } else if let error = remote.transferFailures[job.id] {
                        Text(error).font(p.font(12)).foregroundStyle(p.danger)
                        Button("Réessayer l’import") { remote.requestAutomaticImport(job); remote.processAutomaticImports(library: library) }.font(p.font(12))
                        Button("Télécharger à nouveau depuis la source") { Task { await remote.download(manga, chapter: chapter) } }.font(p.font(12))
                    } else { Text(remote.isAwaitingImport(job) ? "Ajout à la bibliothèque…" : "Disponible sur le Mac").font(p.font(13)).foregroundStyle(p.muted) }
                }
                if job?.state == "cancelled" { Text("Téléchargement annulé").font(p.font(12)).foregroundStyle(p.muted) }
                if let failure {
                    Text(failure).font(p.font(12)).foregroundStyle(p.danger).accessibilityIdentifier("downloadError-\(chapter.id)")
                    Button("Réessayer") { Task { await remote.download(manga, chapter: chapter) } }.font(p.font(12)).disabled(requesting || active)
                }
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            Button(action: activate) {
                Group {
                    if requesting || active { ProgressView().tint(p.paper) }
                    else { Image(systemName: local != nil ? "checkmark" : pending ? "clock" : failure != nil ? "arrow.clockwise" : "arrow.down").font(.system(size: 18, weight: .medium)) }
                }.frame(width: 44, height: 44).foregroundStyle(p.paper).background(p.ink, in: Circle()).contentShape(Circle())
            }.buttonStyle(.plain).disabled(local == nil && (requesting || active || pending || !remote.connected))
                .accessibilityIdentifier(local != nil ? "readChapter-\(chapter.id)" : "download-\(chapter.id)")
                .accessibilityLabel(local != nil ? "Lire" : "Télécharger \(chapter.title)")
        }.padding(.vertical, 10)
    }
    private func activate() {
        if let local { library.open(local) }
        else if completed, let job { remote.requestAutomaticImport(job); remote.processAutomaticImports(library: library) }
        else { Task { await remote.download(manga, chapter: chapter) } }
    }
}
