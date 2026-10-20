import XCTest

@testable import MangaFlow

final class AniListClientTests: XCTestCase {
  private func session(status: Int, body: String) -> URLSession {
    MetadataProtocol.status = status
    MetadataProtocol.body = Data(body.utf8)
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MetadataProtocol.self]
    return URLSession(configuration: config)
  }
  func testSearchUsesPublicMangaQueryAndDecodesCover() async throws {
    let session = session(
      status: 200,
      body:
        #"{"data":{"Page":{"media":[{"id":30011,"title":{"romaji":"NARUTO"},"coverImage":{"large":"https://example.com/naruto.jpg"}}]}}}"#
    )
    defer { session.invalidateAndCancel() }
    let result = try await AniListClient(session: session).search("Naruto")
    XCTAssertEqual(result.first?.id, 30011)
    XCTAssertEqual(result.first?.coverImage?.large, "https://example.com/naruto.jpg")
    XCTAssertNil(MetadataProtocol.request?.value(forHTTPHeaderField: "Authorization"))
    let body = try XCTUnwrap(MetadataProtocol.request?.httpBody ?? MetadataProtocol.sentBody)
    XCTAssertTrue(String(decoding: body, as: UTF8.self).contains("type:MANGA"))
  }
  func testLookupRefreshesSelectedMediaPublicationStatusByID() async throws {
    let session = session(status: 200, body: #"{"data":{"Media":{"id":30011,"title":{"romaji":"NARUTO"},"status":"FINISHED","chapters":700}}}"#)
    defer { session.invalidateAndCancel() }
    let result = try await AniListClient(session: session).media(30011)
    XCTAssertEqual(result.status, "FINISHED")
    XCTAssertEqual(result.chapters, 700)
    let body = try XCTUnwrap(MetadataProtocol.request?.httpBody ?? MetadataProtocol.sentBody)
    let query = String(decoding: body, as: UTF8.self)
    XCTAssertTrue(query.contains("status chapters"))
    XCTAssertTrue(query.contains("30011"))
  }
  func testGraphQLErrorDoesNotEraseAValidCover() async throws {
    let session = session(status: 200, body: #"{"data":null,"errors":[{"message":"Unavailable"}]}"#)
    defer { session.invalidateAndCancel() }
    do {
      _ = try await AniListClient(session: session).search("Naruto")
      XCTFail("Expected GraphQL error")
    } catch let error as RemoteFailure { XCTAssertEqual(error.code, "metadata_failed") }
  }
  func testRateLimitHasActionableErrorWithoutImmediateRetry() async throws {
    let session = session(status: 429, body: "{}")
    defer { session.invalidateAndCancel() }
    do {
      _ = try await AniListClient(session: session).search("Naruto")
      XCTFail("Expected rate limit")
    } catch let error as RemoteFailure { XCTAssertEqual(error.code, "metadata_rate_limit") }
  }
    func testAniListPublicationStateIsDistinctFromReadingOrLatestChapter() throws {
        let finished = try JSONDecoder().decode(MangaMetadata.self, from: Data(#"{"id":1,"title":{"romaji":"Test"},"status":"FINISHED","chapters":10}"#.utf8))
        XCTAssertEqual(finished.publicationLabel, "Publication terminée")
        XCTAssertEqual(finished.chapters, 10)
        let ongoing = try JSONDecoder().decode(MangaMetadata.self, from: Data(#"{"id":2,"title":{"romaji":"Test"},"status":"RELEASING","chapters":null}"#.utf8))
        XCTAssertEqual(ongoing.publicationLabel, "En publication")
        XCTAssertNil(ongoing.chapters)
        let legacy = try JSONDecoder().decode(MangaMetadata.self, from: Data(#"{"id":3,"title":{"romaji":"Old"}}"#.utf8))
        XCTAssertNil(legacy.publicationLabel)
    }
}
private final class MetadataProtocol: URLProtocol, @unchecked Sendable {
  static var status = 200
  static var body = Data()
  static var request: URLRequest?
  static var sentBody: Data?
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.request = request
    if let stream = request.httpBodyStream {
      stream.open()
      defer { stream.close() }
      var output = Data()
      var buffer = [UInt8](repeating: 0, count: 4096)
      while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 { break }
        output.append(contentsOf: buffer.prefix(count))
      }
      Self.sentBody = output
    }
    client?.urlProtocol(
      self,
      didReceive: HTTPURLResponse(
        url: request.url!, statusCode: Self.status, httpVersion: nil,
        headerFields: ["Content-Type": "application/json", "Retry-After": "60"])!,
      cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Self.body)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}
