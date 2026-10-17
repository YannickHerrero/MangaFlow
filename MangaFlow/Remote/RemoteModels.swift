import Foundation

struct PairingPayload: Codable {
    let type: String
    let version: Int
    let serverURL: String
    let serverID: String
    let secret: String
    let expiresAt: String

    func validatedURL(now: Date = Date()) throws -> URL {
        let date = ISO8601DateFormatter()
        date.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parsed = URL(string: serverURL)
        let hostParts = parsed?.host?.split(separator: ".", omittingEmptySubsequences: false) ?? []
        let parts = hostParts.compactMap { Int($0) }
        let privateIPv4 = hostParts.count == 4 && parts.count == 4 && parts.allSatisfy { (0...255).contains($0) } &&
            (parts[0] == 10 || (parts[0] == 192 && parts[1] == 168) || (parts[0] == 172 && (16...31).contains(parts[1])))
        var transportValid = parsed?.scheme == "https" ||
            (parsed?.scheme == "http" && ((parsed?.host?.hasSuffix(".local") ?? false) || privateIPv4))
        #if DEBUG && targetEnvironment(simulator)
        transportValid = transportValid || (parsed?.scheme == "http" && parsed?.host == "127.0.0.1" && parsed?.port == 9120)
        #endif
        guard type == "mangaflow-pairing", version == 1, UUID(uuidString: serverID) != nil,
              secret.count >= 32, secret.count <= 128,
              let expiration = date.date(from: expiresAt), expiration > now,
              expiration.timeIntervalSince(now) <= 600,
              let url = URL(string: serverURL), let host = url.host,
              transportValid,
              host.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-") }),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/", (url.port ?? 443) > 0 else {
            throw RemoteFailure(code: "pairing_invalid", message: "QR code invalide ou expiré. Génère un nouveau code sur le Mac.")
        }
        return url
    }
}
struct ServerConnection: Codable {
    let serverURL: URL
    let serverID: String
    let deviceID: String
    let token: String
}
struct RemoteFailure: Error, LocalizedError, Codable {
    let code: String
    let message: String
    var errorDescription: String? {
        switch code {
        case "server_unreachable": return "Mac injoignable. Vérifie que le Mac et cet appareil sont sur le même réseau local, que le Mac est allumé et que le serveur fonctionne."
        case "authentication_invalid", "pairing_invalid": return "Appairage invalide, révoqué ou expiré. Relie à nouveau cet appareil au Mac."
        case "catalog_not_synced": return "Le catalogue local n’est pas encore synchronisé. Lance son actualisation."
        case "source_unavailable": return "La source ou le moteur est indisponible. Réessaie depuis le Mac."
        case "connector_broken", "connector_incompatible": return "Le connecteur ne fonctionne pas avec cette source. Consulte le diagnostic du Mac."
        case "chapter_unavailable", "image_unavailable": return "Le chapitre ou une de ses images est indisponible. Aucun CBZ incomplet n’a été publié."
        case "network_failed": return "La connexion au site a échoué. Tu peux relancer la tâche."
        default: return message
        }
    }
}
struct RemoteSource: Codable, Identifiable, Hashable {
    struct Capabilities: Codable, Hashable { let catalog: Bool; let chapters: Bool; let download: Bool }
    struct Catalog: Codable, Hashable { let syncedAt: String?; let state: String; let lastError: RemoteFailure? }
    let id: String
    let name: String
    let languages: [String]
    let tags: [String]
    let capabilities: Capabilities
    let availability: String
    let explanation: String?
    let catalog: Catalog
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id && lhs.catalog.state == rhs.catalog.state && lhs.catalog.syncedAt == rhs.catalog.syncedAt }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
struct RemoteManga: Codable, Identifiable, Hashable {
    let id: String
    let sourceID: String
    let title: String
}
struct RemoteChapter: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let language: String?
    let order: Int
}
struct RemoteJob: Codable, Identifiable {
    struct Target: Codable { let sourceID: String; let manga: RemoteManga?; let chapter: RemoteChapter? }
    struct Progress: Codable { let completed: Int; let total: Int }
    struct Result: Codable { let chapters: [RemoteChapter]?; let count: Int? }
    let id: String
    let kind: String
    let target: Target
    let state: String
    let progress: Progress
    let error: RemoteFailure?
    let artifactID: String?
    let result: Result?
    var queuePosition: Int? = nil
    var createdAt: String? = nil
    var startedAt: String? = nil
    var updatedAt: String? = nil
    var finished: Bool { ["completed", "failed", "cancelled"].contains(state) }
    var stateLabel: String {
        ["queued": "En attente", "running": "En cours", "completed": "Terminé", "failed": "Échec", "cancelled": "Annulé"][state] ?? state
    }
}
struct RemoteArtifact: Codable {
    let id: String
    let filename: String
    let size: Int64
    let sha256: String
}
struct ServerHealth: Codable { let apiVersion: Int; let serverID: String }
struct RemoteStatus: Codable {
    struct Update: Codable { let state: String?; let lastError: RemoteFailure? }
    let engineVersion: String
    let update: Update
}
extension RemoteFailure: Hashable {}
