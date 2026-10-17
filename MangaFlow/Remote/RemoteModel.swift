import SwiftUI

@Observable @MainActor
final class RemoteModel {
    var connection: ServerConnection?
    var sources: [RemoteSource] = []
    var jobs: [RemoteJob] = []
    var status: RemoteStatus?
    var error: String?
    var connected = false
    var busy = false
    var importing = false
    var sourceSearch = ""
    private(set) var requestingDownloads: Set<ChapterDownloadKey> = []
    private(set) var downloadErrors: [ChapterDownloadKey: String] = [:]
    private var acceptedDownloads: [String: RemoteJob] = [:]
    private(set) var client: RemoteAPI?
    init() {
        do { connection = try ConnectionVault.load() }
        catch { self.error = error.localizedDescription }
        if let connection { client = RemoteAPI(connection: connection) }
    }
    init(connection: ServerConnection?, session: URLSession) {
        self.connection = connection
        if let connection { client = RemoteAPI(connection: connection, session: session) }
    }
    func pair(_ text: String) async {
        guard !busy else { return }; busy = true; error = nil
        defer { busy = false }
        do {
            let payload = try JSONDecoder().decode(PairingPayload.self, from: Data(text.utf8))
            let credentials = try await RemoteAPI.pair(payload, deviceName: UIDevice.current.name)
            try ConnectionVault.save(credentials)
            connection = credentials; client = RemoteAPI(connection: credentials)
            await refresh()
        } catch { report(error) }
    }
    func refresh(silent: Bool = false) async {
        guard let client else { return }
        do {
            let updated = try await client.jobs()
            acceptedDownloads = acceptedDownloads.filter { entry in !updated.contains { $0.id == entry.key } }
            jobs = Array(acceptedDownloads.values) + updated
            sources = try await client.sources()
            status = try await client.status()
            connected = true
        } catch is CancellationError {} catch { connected = false; if !silent { report(error) } }
    }
    func forget() {
        ConnectionVault.clear(); connection = nil; client = nil; connected = false
        sources = []; jobs = []; status = nil
        requestingDownloads = []; downloadErrors = [:]; acceptedDownloads = [:]
    }
    func revoke() async {
        do { try await client?.revoke(); forget() } catch { report(error) }
    }
    func synchronize(_ source: RemoteSource) async {
        guard let client else { return }
        do { _ = try await client.create("catalog", target: .init(sourceID: source.id, manga: nil, chapter: nil)); await refresh() }
        catch { report(error) }
    }
    func cancel(_ job: RemoteJob) async {
        do { _ = try await client?.cancel(job.id); await refresh() } catch { report(error) }
    }
    func downloadJob(for manga: RemoteManga, chapter: RemoteChapter) -> RemoteJob? {
        jobs.first {
            $0.kind == "download" && $0.target.sourceID == manga.sourceID &&
            $0.target.manga?.id == manga.id && $0.target.chapter?.id == chapter.id
        }
    }
    func download(_ manga: RemoteManga, chapter: RemoteChapter) async {
        let key = ChapterDownloadKey(manga: manga, chapter: chapter)
        guard !requestingDownloads.contains(key) else { return }
        if let current = downloadJob(for: manga, chapter: chapter), !current.finished { return }
        requestingDownloads.insert(key); downloadErrors[key] = nil
        defer { requestingDownloads.remove(key) }
        guard let client else {
            let failure = RemoteFailure(code: "authentication_invalid", message: "Relie cet appareil au Mac avant de télécharger.")
            downloadErrors[key] = failure.localizedDescription; report(failure); return
        }
        do {
            let created = try await client.create("download", target: .init(sourceID: manga.sourceID, manga: manga, chapter: chapter))
            // Reflect acceptance immediately, without waiting for the next polling cycle.
            acceptedDownloads[created.id] = created
            jobs.removeAll { $0.id == created.id }; jobs.insert(created, at: 0)
        } catch is CancellationError {} catch {
            downloadErrors[key] = error.localizedDescription
            report(error)
        }
    }
    func importArtifact(_ job: RemoteJob, library: LibraryModel) async {
        guard !importing, let client, let artifactID = job.artifactID else { return }
        importing = true; defer { importing = false }
        do {
            let identity = (connection?.serverID ?? "") + ":" + artifactID
            if let document = library.documents.first(where: { $0.remoteArtifactID == identity }) {
                if document.complete { library.selected = document.id } else { library.resume(document) }
                return
            }
            let url = try await client.download(artifactID)
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            try await library.importRemoteCBZ(url, artifactID: identity, origin: ChapterOrigin(job: job, serverID: connection?.serverID ?? "", sourceName: sources.first { $0.id == job.target.sourceID }?.name))
        } catch { report(error) }
    }
    func report(_ error: Error) { if !(error is CancellationError) { self.error = error.localizedDescription } }
}
