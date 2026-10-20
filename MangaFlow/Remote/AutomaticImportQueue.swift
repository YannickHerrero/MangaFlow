import Foundation
import Observation

struct BatchDownloadEntry: Codable, Identifiable {
  let id: String
  let serverID: String
  let manga: RemoteManga
  let chapter: RemoteChapter
  var error: String?
}

/// Durable user intent. A completed server download is not a completed phone import.
@Observable @MainActor
final class AutomaticImportQueue {
  private(set) var pending: [String: Set<String>]
  private(set) var batch: [BatchDownloadEntry]
  private let defaults: UserDefaults
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    batch = defaults.data(forKey: "batchDownloads").flatMap { try? JSONDecoder().decode([BatchDownloadEntry].self, from: $0) } ?? []
    pending =
      defaults.data(forKey: "automaticImports").flatMap {
        try? JSONDecoder().decode([String: Set<String>].self, from: $0)
      } ?? [:]
  }
  func contains(serverID: String, jobID: String) -> Bool {
    pending[serverID]?.contains(jobID) == true
  }
  func add(serverID: String, jobID: String) {
    pending[serverID, default: []].insert(jobID)
    save()
  }
  func remove(serverID: String, jobID: String) {
    pending[serverID]?.remove(jobID)
    save()
  }
  func enqueue(serverID: String, manga: RemoteManga, chapters: [RemoteChapter]) {
    for chapter in chapters where !batch.contains(where: { $0.serverID == serverID && $0.manga.id == manga.id && $0.manga.sourceID == manga.sourceID && $0.chapter.id == chapter.id }) {
      batch.append(BatchDownloadEntry(id: UUID().uuidString, serverID: serverID, manga: manga, chapter: chapter))
    }
    saveBatch()
  }
  func removeBatch(_ id: String) { batch.removeAll { $0.id == id }; saveBatch() }
  func pauseBatch(_ id: String, error: String) {
    if let index = batch.firstIndex(where: { $0.id == id }) { batch[index].error = error; saveBatch() }
  }
  func retryBatch(serverID: String, manga: RemoteManga) {
    for i in batch.indices where batch[i].serverID == serverID && batch[i].manga.id == manga.id && batch[i].manga.sourceID == manga.sourceID { batch[i].error = nil }
    saveBatch()
  }
  func cancelBatch(serverID: String, manga: RemoteManga) {
    batch.removeAll { $0.serverID == serverID && $0.manga.id == manga.id && $0.manga.sourceID == manga.sourceID }; saveBatch()
  }
  private func saveBatch() { if let data = try? JSONEncoder().encode(batch) { defaults.set(data, forKey: "batchDownloads") } }
  private func save() {
    if let data = try? JSONEncoder().encode(pending) {
      defaults.set(data, forKey: "automaticImports")
    }
  }
}
