import Foundation
import Observation

/// Durable user intent. A completed server download is not a completed phone import.
@Observable @MainActor
final class AutomaticImportQueue {
  private(set) var pending: [String: Set<String>]
  private let defaults: UserDefaults
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
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
  private func save() {
    if let data = try? JSONEncoder().encode(pending) {
      defaults.set(data, forKey: "automaticImports")
    }
  }
}
