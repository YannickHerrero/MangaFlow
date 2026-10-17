import Foundation
import CryptoKit

actor RemoteAPI {
    let connection: ServerConnection
    private let session: URLSession
    init(connection: ServerConnection, session: URLSession = .shared) { self.connection = connection; self.session = session }

    static func pair(_ payload: PairingPayload, deviceName: String) async throws -> ServerConnection {
        let url = try payload.validatedURL()
        let provisional = ServerConnection(serverURL: url, serverID: payload.serverID, deviceID: "", token: "")
        let client = RemoteAPI(connection: provisional)
        let health: ServerHealth = try await client.send("GET", "health", authenticated: false)
        guard health.apiVersion == 1, health.serverID == payload.serverID else {
            throw RemoteFailure(code: "pairing_invalid", message: "Ce code ne correspond pas à ce serveur.")
        }
        struct Exchange: Encodable { let secret: String; let serverID: String; let deviceName: String }
        struct Credentials: Decodable { let deviceID: String; let token: String; let serverID: String }
        let credentials: Credentials = try await client.send("POST", "pair/exchange", body: JSONEncoder().encode(Exchange(secret: payload.secret, serverID: payload.serverID, deviceName: deviceName)), authenticated: false)
        guard credentials.serverID == payload.serverID else { throw RemoteFailure(code: "pairing_invalid", message: "Identité serveur différente.") }
        return ServerConnection(serverURL: url, serverID: credentials.serverID, deviceID: credentials.deviceID, token: credentials.token)
    }
    func send<T: Decodable>(_ method: String, _ path: String, query: [String: String] = [:], body: Data? = nil, authenticated: Bool = true, idempotencyKey: String? = nil) async throws -> T {
        var components = URLComponents(url: connection.serverURL.appending(path: "api/v1/" + path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated { request.setValue("Bearer " + connection.token, forHTTPHeaderField: "Authorization") }
        if let idempotencyKey { request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key") }
        do {
            let (data, response) = try await session.data(for: request)
            try Self.check(response, data: data)
            return try JSONDecoder().decode(T.self, from: data)
        } catch let failure as RemoteFailure { throw failure }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch { throw RemoteFailure(code: "server_unreachable", message: "Mac injoignable.") }
    }
    private static func check(_ response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            struct Envelope: Decodable { let error: RemoteFailure }
            if let error = try? JSONDecoder().decode(Envelope.self, from: data).error { throw error }
            throw RemoteFailure(code: "network_failed", message: "Réponse du serveur invalide.")
        }
    }
    func sources(query: String = "") async throws -> [RemoteSource] {
        struct Response: Decodable { let sources: [RemoteSource] }
        let response: Response = try await send("GET", "sources", query: ["q": query]); return response.sources
    }
    func catalog(_ sourceID: String, query: String, offset: Int = 0) async throws -> ([RemoteManga], Int) {
        struct Response: Decodable { let mangas: [RemoteManga]; let total: Int }
        let response: Response = try await send("GET", "catalog", query: ["sourceID": sourceID, "q": query, "offset": String(offset), "limit": "50"])
        return (response.mangas, response.total)
    }
    func create(_ kind: String, target: RemoteJob.Target, key: String = UUID().uuidString) async throws -> RemoteJob {
        let endpoint = ["catalog": "catalog/sync", "chapters": "chapters", "download": "downloads"][kind]!
        return try await send("POST", endpoint, body: JSONEncoder().encode(target), idempotencyKey: key)
    }
    func jobs() async throws -> [RemoteJob] {
        struct Response: Decodable { let jobs: [RemoteJob] }
        let response: Response = try await send("GET", "jobs"); return response.jobs
    }
    func job(_ id: String) async throws -> RemoteJob { try await send("GET", "jobs/" + id) }
    func cancel(_ id: String) async throws -> RemoteJob { try await send("POST", "jobs/" + id + "/cancel") }
    func status() async throws -> RemoteStatus { try await send("GET", "server") }
    func revoke() async throws {
        struct Response: Decodable { let revoked: Bool }
        let _: Response = try await send("DELETE", "device")
    }
    func download(_ artifactID: String) async throws -> URL {
        let artifact: RemoteArtifact = try await send("GET", "artifacts/" + artifactID)
        var request = URLRequest(url: connection.serverURL.appending(path: "api/v1/artifacts/" + artifactID + "/file"))
        request.setValue("Bearer " + connection.token, forHTTPHeaderField: "Authorization"); request.timeoutInterval = 300
        do {
            let (temporary, response) = try await session.download(for: request)
            defer { try? FileManager.default.removeItem(at: temporary) }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                try Self.check(response, data: (try? Data(contentsOf: temporary)) ?? Data())
                throw RemoteFailure(code: "network_failed", message: "Téléchargement incomplet.")
            }
            let data = try Data(contentsOf: temporary, options: .mappedIfSafe)
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard Int64(data.count) == artifact.size, digest == artifact.sha256 else { throw RemoteFailure(code: "transfer_invalid", message: "Le transfert CBZ est incomplet ou corrompu. Réessaie.") }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = URL(fileURLWithPath: artifact.filename).lastPathComponent
            let destination = folder.appendingPathComponent(name)
            try FileManager.default.moveItem(at: temporary, to: destination)
            return destination
        } catch let error as RemoteFailure { throw error }
        catch is CancellationError { throw CancellationError() }
        catch { throw RemoteFailure(code: "server_unreachable", message: "Transfert interrompu. Le CBZ reste disponible sur le Mac.") }
    }
}
