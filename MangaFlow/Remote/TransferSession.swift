import Foundation

/// One authenticated foreground transfer. Server downloads survive disconnection;
/// interrupted phone transfers restart from the validated artifact.
final class TransferSession: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
  private let progress: @Sendable (Double) -> Void
  private let lock = NSLock()
  private var continuation: CheckedContinuation<(URL, URLResponse), Error>?
  private var session: URLSession?
  private var task: URLSessionDownloadTask?
  private var cancelled = false
  init(progress: @escaping @Sendable (Double) -> Void) { self.progress = progress }
  func download(_ request: URLRequest) async throws -> (URL, URLResponse) {
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        lock.lock()
        defer { lock.unlock() }
        if cancelled {
          continuation.resume(throwing: CancellationError())
          return
        }
        self.continuation = continuation
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session
        task = session.downloadTask(with: request)
        task?.resume()
      }
    } onCancel: {
      self.cancel()
    }
  }
  private func cancel() {
    lock.lock()
    cancelled = true
    task?.cancel()
    lock.unlock()
  }
  func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
  ) {
    if totalBytesExpectedToWrite > 0 {
      progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }
  }
  func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    do {
      let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try FileManager.default.moveItem(at: location, to: file)
      guard let response = downloadTask.response else { throw URLError(.badServerResponse) }
      finish(.success((file, response)))
    } catch { finish(.failure(error)) }
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error { finish(.failure(error)) }
  }
  private func finish(_ result: Result<(URL, URLResponse), Error>) {
    lock.lock()
    let continuation = self.continuation
    self.continuation = nil
    let session = self.session
    self.session = nil
    lock.unlock()
    continuation?.resume(with: result)
    session?.finishTasksAndInvalidate()
  }
}
