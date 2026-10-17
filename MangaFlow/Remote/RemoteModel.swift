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
    let automaticImports: AutomaticImportQueue
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
        transferTask = Task { defer { transferTask = nil }; await importArtifact(job, library: library) }
    }
    func cancelTransfer(library: LibraryModel) {
        if let job = jobs.first(where: { $0.id == transferJobID }) { clearAutomaticImport(job) }
        transferTask?.cancel(); if transferPhase == "Découpage sur cet appareil" { library.cancel() } }

    private(set) var requestingDownloads: Set<ChapterDownloadKey> = []
    private(set) var downloadErrors: [ChapterDownloadKey: String] = [:]
    private var acceptedDownloads: [String: RemoteJob] = [:]
    private(set) var client: RemoteAPI?
    init() {
        automaticImports = AutomaticImportQueue()
        do { connection = try ConnectionVault.load() }
        catch { self.error = error.localizedDescription }
        if let connection { client = RemoteAPI(connection: connection); restoreSnapshot(connection.serverID) }
    }
    init(connection: ServerConnection?, session: URLSession, automaticImports: AutomaticImportQueue? = nil) {
        self.automaticImports = automaticImports ?? AutomaticImportQueue()
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
        clearAutomaticImport(job)
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
        if let current = downloadJob(for: manga, chapter: chapter), !current.finished {
            requestAutomaticImport(current); return
        }
        requestingDownloads.insert(key); downloadErrors[key] = nil
        defer { requestingDownloads.remove(key) }
        guard let client else {
            let failure = RemoteFailure(code: "authentication_invalid", message: "Relie cet appareil au Mac avant de télécharger.")
            downloadErrors[key] = failure.localizedDescription; report(failure); return
        }
        if let serverID = connection?.serverID {
            automaticImports.add(serverID: serverID, jobID: Self.importTarget(manga: manga, chapter: chapter))
        }
        do {
            let created = try await client.create("download", target: .init(sourceID: manga.sourceID, manga: manga, chapter: chapter))
            requestAutomaticImport(created)
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
    func importArtifact(_ job: RemoteJob, library: LibraryModel, openWhenComplete: Bool = true) async {
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
                if document.complete && document.engineVersion == MangaDocument.engine {
                    if openWhenComplete { library.selected = document.id }
                } else {
                    transferPhase = "Découpage sur cet appareil"
                    library.error = nil
                    await library.resume(document, openWhenComplete: openWhenComplete)?.value
                    if let error = library.error { throw RemoteFailure(code: "import_failed", message: error) }
                    guard library.documents.contains(where: { $0.id == document.id && $0.complete }) else { throw CancellationError() }
                }
                clearAutomaticImport(job)
                return
            }
            let url = try await client.download(artifactID) { [weak self] value in
                Task { @MainActor in self?.transferProgress = value }
            }
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            try Task.checkCancellation()
            transferPhase = "Découpage sur cet appareil"
            try await library.importRemoteCBZ(url, artifactID: identity, origin: ChapterOrigin(job: job, serverID: connection?.serverID ?? "", sourceName: sources.first { $0.id == job.target.sourceID }?.name), openWhenComplete: openWhenComplete)
            clearAutomaticImport(job)
            importedJobs.insert(job.id); UserDefaults.standard.set(Array(importedJobs), forKey: "importedJobs")
        } catch is CancellationError {
            setTransferFailure(job.id, "Import interrompu. Tu peux le reprendre.")
        } catch {
            setTransferFailure(job.id, error.localizedDescription); report(error)
        }
    }
    func requestAutomaticImport(_ job: RemoteJob) {
        guard let serverID = connection?.serverID else { return }
        setTransferFailure(job.id, nil)
        automaticImports.add(serverID: serverID, jobID: job.id)
    }
    func isAwaitingImport(_ job: RemoteJob) -> Bool {
        guard let serverID = connection?.serverID else { return false }
        if automaticImports.contains(serverID: serverID, jobID: job.id) { return true }
        guard let target = Self.importTarget(job) else { return false }
        return automaticImports.contains(serverID: serverID, jobID: target) && jobs.first(where: { Self.importTarget($0) == target })?.id == job.id
    }
    static func importTarget(manga: RemoteManga, chapter: RemoteChapter) -> String {
        "target:" + ChapterOrigin.key(manga.sourceID, manga.id, chapter.id)
    }
    private static func importTarget(_ job: RemoteJob) -> String? {
        guard job.kind == "download", let manga = job.target.manga, let chapter = job.target.chapter else { return nil }
        return importTarget(manga: manga, chapter: chapter)
    }
    private func clearAutomaticImport(_ job: RemoteJob) {
        guard let serverID = connection?.serverID else { return }
        automaticImports.remove(serverID: serverID, jobID: job.id)
        if let target = Self.importTarget(job), jobs.first(where: { Self.importTarget($0) == target })?.id == job.id {
            automaticImports.remove(serverID: serverID, jobID: target)
        }
    }
    func localDocument(for job: RemoteJob, library: LibraryModel) -> MangaDocument? {
        guard let serverID = connection?.serverID else { return nil }
        let origin = ChapterOrigin(job: job, serverID: serverID, sourceName: nil)
        return library.documents.first {
            $0.remoteArtifactID == serverID + ":" + (job.artifactID ?? "") ||
            (origin != nil && $0.origin?.seriesID == origin?.seriesID && $0.origin?.chapterID == origin?.chapterID)
        }
    }
    var activeDownloadCount: Int {
        var active = Set(jobs.filter {
            $0.kind == "download" && (!$0.finished || (isAwaitingImport($0) && transferFailures[$0.id] == nil))
        }.map(\.id))
        if let transferJobID { active.insert(transferJobID) }
        return active.count
    }
    func processAutomaticImports(library: LibraryModel) {
        guard connected, connection != nil, !importing, !library.isBusy, transferTask == nil else { return }
        for job in jobs where isAwaitingImport(job) && ["failed", "cancelled"].contains(job.state) {
            clearAutomaticImport(job)
        }
        guard let job = jobs.reversed().first(where: {
            $0.kind == "download" && $0.state == "completed" && $0.artifactID != nil &&
            isAwaitingImport($0) && transferFailures[$0.id] == nil
        }) else { return }
        transferTask = Task {
            defer { transferTask = nil }
            await importArtifact(job, library: library, openWhenComplete: false)
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
