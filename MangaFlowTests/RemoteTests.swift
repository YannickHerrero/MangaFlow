import XCTest
@testable import MangaFlow

final class RemoteTests: XCTestCase {
    private func payload(url: String = "http://mac.local:9120", expiration: Date = Date().addingTimeInterval(120)) -> PairingPayload {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return PairingPayload(type: "mangaflow-pairing", version: 1, serverURL: url, serverID: UUID().uuidString, secret: String(repeating: "a", count: 43), expiresAt: formatter.string(from: expiration))
    }
    func testPairingAcceptsLANAndRejectsUnsafeURLsBeforeSendingSecret() throws {
        XCTAssertEqual(try payload().validatedURL().host, "mac.local")
        XCTAssertEqual(try payload(url: "http://192.168.1.29:9120").validatedURL().host, "192.168.1.29")
        XCTAssertNoThrow(try payload(url: "https://custom.example:9443").validatedURL())
        for url in ["http://public.example", "http://10.1.2.3.example.com", "http://mac.local.evil.com", "http://user:password@mac.local", "http://mac.local/path", "http://mac.local?secret=foo", "file:///private/tmp/data"] {
            XCTAssertThrowsError(try payload(url: url).validatedURL(), url)
        }
        XCTAssertThrowsError(try payload(expiration: Date().addingTimeInterval(-1)).validatedURL())
        XCTAssertThrowsError(try payload(expiration: Date().addingTimeInterval(3600)).validatedURL())
    }
    func testOpaqueIDsAndOptionalJobMetadataDecodeWithoutRouteAssumptions() throws {
        let data = Data("""
        {"id":"job-id","kind":"download","target":{"sourceID":"fixture","manga":{"id":"/title?q=é/#","sourceID":"fixture","title":"Manga"},"chapter":{"id":"https://site/chapter?c=2","title":"Chapter","order":0}},"state":"running","progress":{"completed":3,"total":5}}
        """.utf8)
        let job = try JSONDecoder().decode(RemoteJob.self, from: data)
        XCTAssertEqual(job.target.manga?.id, "/title?q=é/#")
        XCTAssertEqual(job.target.chapter?.id, "https://site/chapter?c=2")
        XCTAssertFalse(job.finished)
        XCTAssertNil(job.artifactID)
    }
    func testLegacyDocumentsStillDecodeWithoutRemoteArtifactIdentity() throws {
        let document = MangaDocument(id: UUID(), title: "Offline", pages: [])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as? [String: Any])
        json.removeValue(forKey: "remoteArtifactID")
        let decoded = try JSONDecoder().decode(MangaDocument.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.remoteArtifactID)
        XCTAssertEqual(decoded.title, "Offline")
    }
}
