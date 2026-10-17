import SwiftUI

struct ChapterDownloadRow: View {
    @Bindable var remote: RemoteModel
    let library: LibraryModel
    let manga: RemoteManga
    let chapter: RemoteChapter
    private var key: ChapterDownloadKey { ChapterDownloadKey(manga: manga, chapter: chapter) }
    private var job: RemoteJob? { remote.downloadJob(for: manga, chapter: chapter) }
    private var requesting: Bool { remote.requestingDownloads.contains(key) }
    private var active: Bool { job.map { !$0.finished } ?? false }
    private var completed: Bool { job?.state == "completed" && job?.artifactID != nil }
    private var failure: String? { remote.downloadErrors[key] ?? job?.error?.localizedDescription }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chapter.title)
                    if let language = chapter.language, !language.isEmpty {
                        Text(language).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    Task { await remote.download(manga, chapter: chapter) }
                } label: {
                    if requesting || active { ProgressView() }
                    else { Image(systemName: completed ? "checkmark.circle.fill" : failure != nil ? "arrow.clockwise.circle" : "arrow.down.circle") }
                }
                .disabled(requesting || active || completed)
                .accessibilityLabel(completed ? "Téléchargé \(chapter.title)" : "Télécharger \(chapter.title)")
                .accessibilityIdentifier("download-\(chapter.id)")
            }
            if requesting {
                Text("Envoi de la demande…").font(.caption).foregroundStyle(.secondary)
            } else if let job {
                if active {
                    Text(job.state == "queued" ? "En attente sur le Mac" : "Téléchargement en cours sur le Mac")
                        .font(.caption).foregroundStyle(.secondary)
                    if job.progress.total > 0 {
                        ProgressView(value: Double(job.progress.completed), total: Double(job.progress.total))
                        Text("\(job.progress.completed) / \(job.progress.total) images").font(.caption).foregroundStyle(.secondary)
                    }
                } else if completed {
                    Text("Téléchargé sur le Mac").font(.caption).foregroundStyle(.secondary)
                    Button(remote.importing ? "Import en cours…" : "Importer et lire") {
                        Task { await remote.importArtifact(job, library: library) }
                    }
                    .disabled(remote.importing || library.isBusy)
                    .accessibilityIdentifier("readChapter-\(chapter.id)")
                } else if job.state == "cancelled" {
                    Text("Téléchargement annulé").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let failure {
                Text(failure).font(.caption).foregroundStyle(.orange)
                    .accessibilityIdentifier("downloadError-\(chapter.id)")
                Button("Réessayer") { Task { await remote.download(manga, chapter: chapter) } }
                    .disabled(requesting || active)
            }
        }.padding(.vertical, 4)
        .buttonStyle(.borderless)

    }
}
