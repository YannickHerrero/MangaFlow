import XCTest

@testable import MangaFlow

@MainActor final class AutomaticImportTests: XCTestCase {
  private var defaults: UserDefaults!
  private var suite: String!
  private var root: URL!
  override func setUpWithError() throws {
    suite = "auto-import-tests-" + UUID().uuidString
    defaults = UserDefaults(suiteName: suite)!
    root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  }
  override func tearDownWithError() throws {
    defaults.removePersistentDomain(forName: suite)
    try? FileManager.default.removeItem(at: root)
  }
  private func job(state: String = "completed", id: String = UUID().uuidString) -> RemoteJob {
    RemoteJob(
      id: id, kind: "download",
      target: .init(
        sourceID: "source", manga: RemoteManga(id: "/manga", sourceID: "source", title: "Manga"),
        chapter: RemoteChapter(id: "/chapter", title: "1", language: nil, order: 1)), state: state,
      progress: .init(completed: 1, total: 1), error: nil, artifactID: "artifact", result: nil)
  }
  private func model() -> RemoteModel {
    let model = RemoteModel(
      connection: ServerConnection(
        serverURL: URL(string: "https://fixture.invalid")!, serverID: "server", deviceID: "device",
        token: "fixture"), session: .shared,
      automaticImports: AutomaticImportQueue(defaults: defaults))
    model.connected = true
    return model
  }
  func testIntentSurvivesRelaunchAndSeparatesServers() {
    let queue = AutomaticImportQueue(defaults: defaults)
    queue.add(serverID: "a", jobID: "job")
    let restored = AutomaticImportQueue(defaults: defaults)
    XCTAssertTrue(restored.contains(serverID: "a", jobID: "job"))
    XCTAssertFalse(restored.contains(serverID: "b", jobID: "job"))
    restored.remove(serverID: "a", jobID: "job")
    XCTAssertFalse(AutomaticImportQueue(defaults: defaults).contains(serverID: "a", jobID: "job"))
  }
  func testCompletedLocalImportIsNotOpenedOrDuplicated() async {
    let remote = model()
    let job = job()
    let library = LibraryModel(store: DocumentStore(root: root))
    var document = MangaDocument(id: UUID(), title: "Existing", pages: [])
    document.remoteArtifactID = "server:artifact"
    library.documents = [document]
    remote.jobs = [job]
    remote.requestAutomaticImport(job)
    remote.processAutomaticImports(library: library)
    await remote.transferTask?.value
    XCTAssertNil(library.selected)
    XCTAssertEqual(library.documents.count, 1)
    XCTAssertFalse(remote.isAwaitingImport(job))
  }
  func testBusyLibraryDefersRatherThanLosingIntent() {
    let remote = model()
    let job = job()
    let library = LibraryModel(store: DocumentStore(root: root))
    remote.jobs = [job]
    remote.requestAutomaticImport(job)
    library.isBusy = true
    remote.processAutomaticImports(library: library)
    XCTAssertNil(remote.transferTask)
    XCTAssertTrue(remote.isAwaitingImport(job))
  }
  func testFailedImportWaitsForExplicitRetryAndRetryClearsError() {
    let remote = model()
    let job = job()
    let library = LibraryModel(store: DocumentStore(root: root))
    remote.jobs = [job]
    remote.requestAutomaticImport(job)
    remote.transferFailures[job.id] = "Interrupted"
    remote.processAutomaticImports(library: library)
    XCTAssertNil(remote.transferTask)
    remote.requestAutomaticImport(job)
    XCTAssertNil(remote.transferFailures[job.id])
    XCTAssertTrue(remote.isAwaitingImport(job))
  }
  func testFailedServerJobDoesNotRemainAnAutomaticImport() {
    let remote = model()
    let job = job(state: "failed")
    let library = LibraryModel(store: DocumentStore(root: root))
    remote.jobs = [job]
    remote.requestAutomaticImport(job)
    remote.processAutomaticImports(library: library)
    XCTAssertFalse(remote.isAwaitingImport(job))
    XCTAssertNil(remote.transferTask)
  }
  func testIntentBeforeServerResponseMatchesRecoveredJob() {
    let job = job()
    let queue = AutomaticImportQueue(defaults: defaults)
    queue.add(
      serverID: "server",
      jobID: RemoteModel.importTarget(manga: job.target.manga!, chapter: job.target.chapter!))
    let restored = model()
    restored.jobs = [job]
    XCTAssertTrue(restored.isAwaitingImport(job))
    let older = self.job(state: "failed")
    restored.jobs.append(older)
    XCTAssertFalse(restored.isAwaitingImport(older))
  }

  func testActivityCountsPendingPhoneImportWithoutDoubleCountingTransfer() {
    let remote = model()
    let job = job()
    remote.jobs = [job]
    remote.requestAutomaticImport(job)
    XCTAssertEqual(remote.activeDownloadCount, 1)
    remote.transferJobID = job.id
    XCTAssertEqual(remote.activeDownloadCount, 1)
  }

}
