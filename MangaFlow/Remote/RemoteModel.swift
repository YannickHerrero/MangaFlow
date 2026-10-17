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
    private(set) var client: RemoteAPI?
    init() {
        do { connection = try ConnectionVault.load() }
        catch { self.error = error.localizedDescription }
        if let connection { client = RemoteAPI(connection: connection) }
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
            jobs = updated
            sources = try await client.sources()
            status = try await client.status()
            connected = true
        } catch is CancellationError {} catch { connected = false; if !silent { report(error) } }
    }
    func forget() {
        ConnectionVault.clear(); connection = nil; client = nil; connected = false
        sources = []; jobs = []; status = nil
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
    func download(_ manga: RemoteManga, chapter: RemoteChapter) async {
        guard let client else { return }
        do { _ = try await client.create("download", target: .init(sourceID: manga.sourceID, manga: manga, chapter: chapter)); await refresh() }
        catch { report(error) }
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
            try await library.importRemoteCBZ(url, artifactID: identity)
        } catch { report(error) }
    }
    func report(_ error: Error) { if !(error is CancellationError) { self.error = error.localizedDescription } }
}
