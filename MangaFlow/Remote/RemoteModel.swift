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
    var transferFailures: [String: String] = (UserDefaults.standard.dictionary(forKey: "transferFailures") as? [String: String]) ?? [:]
    private func setTransferFailure(_ jobID: String, _ message: String?) {
        transferFailures[jobID] = message
        UserDefaults.standard.set(transferFailures, forKey: "transferFailures")
    }
    var transferProgress: Double = 0
    var transferJobID: String?
    var transferPhase = ""
    var transferTask: Task<Void, Never>?
    var transferStarted: Date?
    var hiddenJobs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "hiddenJobs") ?? [])
    var importedJobs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "importedJobs") ?? [])
    func clearFinishedHistory() {
        hiddenJobs.formUnion(jobs.filter(\.finished).map(\.id))
        UserDefaults.standard.set(Array(hiddenJobs), forKey: "hiddenJobs")
    }
    func startImport(_ job: RemoteJob, library: LibraryModel) {
        guard !importing else { return }
        transferTask = Task { await importArtifact(job, library: library) }
    }
    func cancelTransfer(library: LibraryModel) { transferTask?.cancel(); if transferPhase == "Découpage sur cet appareil" { library.cancel() } }

    private(set) var requestingDownloads: Set<ChapterDownloadKey> = []
    private(set) var downloadErrors: [ChapterDownloadKey: String] = [:]
    private var acceptedDownloads: [String: RemoteJob] = [:]
    private(set) var client: RemoteAPI?
    init() {
        do { connection = try ConnectionVault.load() }
        catch { self.error = error.localizedDescription }
        if let connection { client = RemoteAPI(connection: connection); restoreSnapshot(connection.serverID) }
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
            saveSnapshot()
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
            hiddenJobs.remove(created.id)
            UserDefaults.standard.set(Array(hiddenJobs), forKey: "hiddenJobs")
            jobs.removeAll { $0.id == created.id }; jobs.insert(created, at: 0)
        } catch is CancellationError {} catch {
            downloadErrors[key] = error.localizedDescription
            report(error)
        }
    }
    func importArtifact(_ job: RemoteJob, library: LibraryModel) async {
        guard !importing, let client, let artifactID = job.artifactID else { return }
        importing = true; transferJobID = job.id; transferPhase = "Transfert vers cet appareil"; transferProgress = 0; transferStarted = Date()
        defer { importing = false; transferJobID = nil; transferPhase = ""; UserDefaults.standard.removeObject(forKey: "interruptedTransfer") }
        UserDefaults.standard.set(job.id, forKey: "interruptedTransfer")
        do {
            let identity = (connection?.serverID ?? "") + ":" + artifactID
            let provenance = ChapterOrigin(job: job, serverID: connection?.serverID ?? "", sourceName: sources.first { $0.id == job.target.sourceID }?.name)
            setTransferFailure(job.id, nil)
            if let document = library.documents.first(where: {
                $0.remoteArtifactID == identity || (provenance != nil && $0.origin?.seriesID == provenance?.seriesID && $0.origin?.chapterID == provenance?.chapterID)
            }) {
                library.open(document)
                return
            }
            let url = try await client.download(artifactID) { [weak self] value in
                Task { @MainActor in self?.transferProgress = value }
            }
            try Task.checkCancellation()
            transferPhase = "Découpage sur cet appareil"
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            try await library.importRemoteCBZ(url, artifactID: identity, origin: ChapterOrigin(job: job, serverID: connection?.serverID ?? "", sourceName: sources.first { $0.id == job.target.sourceID }?.name))
            importedJobs.insert(job.id); UserDefaults.standard.set(Array(importedJobs), forKey: "importedJobs")
        } catch is CancellationError {
            setTransferFailure(job.id, "Import interrompu. Tu peux le reprendre.")
        } catch {
            setTransferFailure(job.id, error.localizedDescription); report(error)
        }
    }
    private struct Snapshot: Codable { let sources: [RemoteSource]; let jobs: [RemoteJob] }
    private func snapshotURL(_ serverID: String) -> URL {
        // Server IDs are validated UUIDs by pairing; encode anyway to keep paths opaque.
        let name = Data(serverID.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MangaFlowRemote/" + name + ".json")
    }
    private func saveSnapshot() {
        guard let id = connection?.serverID else { return }
        let file = snapshotURL(id)
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(Snapshot(sources: sources, jobs: jobs)).write(to: file, options: .atomic)
        } catch { /* Optional offline snapshot never blocks authenticated operations. */ }
    }
    private func restoreSnapshot(_ serverID: String) {
        guard let data = try? Data(contentsOf: snapshotURL(serverID)), let saved = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        sources = saved.sources; jobs = saved.jobs
    }
    func report(_ error: Error) { if !(error is CancellationError) { self.error = error.localizedDescription } }
}
