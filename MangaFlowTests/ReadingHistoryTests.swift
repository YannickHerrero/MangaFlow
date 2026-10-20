import XCTest
import UIKit
import ZIPFoundation
@testable import MangaFlow

final class ReadingHistoryTests: XCTestCase {
    @MainActor private func fixture() throws -> (URL, LibraryModel, MangaDocument) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = DocumentStore(root: root)
        let manga = RemoteManga(id: "/blue-lock", sourceID: "lelscan", title: "Blue Lock")
        let chapter = RemoteChapter(id: "/opaque/321", title: "321", language: "fr", order: 40)
        let job = RemoteJob(id: "job", kind: "download", target: .init(sourceID: "lelscan", manga: manga, chapter: chapter), state: "completed", progress: .init(completed: 1, total: 1), error: nil, artifactID: "artifact", result: nil)
        var doc = MangaDocument(id: UUID(), title: "Blue Lock 321", pages: [])
        doc.origin = ChapterOrigin(job: job, serverID: "mac", sourceName: "LELScan")
        doc.readComplete = true; doc.lastReadAt = Date(); doc.lastPanelID = "10-2"
        try store.save(doc)
        try Data(repeating: 42, count: 1024).write(to: store.folder(doc.id).appendingPathComponent("page.jpg"))
        return (root, LibraryModel(store: store), doc)
    }
    @MainActor func testLocalDeletionPreservesSeriesBoundaryAndReadingRecordAfterRelaunch() throws {
        let (root, library, doc) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        library.removeReadChapters()
        XCTAssertTrue(library.documents.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: library.store.folder(doc.id).path))
        let restored = LibraryModel(store: DocumentStore(root: root))
        XCTAssertEqual(restored.series.count, 1)
        XCTAssertEqual(restored.allDocuments.first?.lastPanelID, "10-2")
        XCTAssertEqual(restored.allDocuments.first?.readComplete, true)
        XCTAssertFalse(restored.allDocuments.first!.hasLocalFiles)
        XCTAssertNil(restored.series.first?.resume)
        let manga = RemoteManga(id: "/blue-lock", sourceID: "lelscan", title: "Blue Lock")
        XCTAssertEqual(ChapterListFilter.readBoundary(documents: restored.allDocuments, serverID: "mac", manga: manga, chapters: []), 321)
        restored.edit(restored.allDocuments[0]) { $0.readComplete = false }
        XCTAssertNil(ChapterListFilter.readBoundary(documents: restored.allDocuments, serverID: "mac", manga: manga, chapters: []))
    }
    @MainActor func testCorruptHistoryBlocksDeletionWithoutOverwritingHistory() throws {
        let (root, _, doc) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let file = ReadingHistoryStore(root: root).url
        let corrupt = Data("not-json".utf8); try corrupt.write(to: file)
        let library = LibraryModel(store: DocumentStore(root: root))
        library.error = nil; library.removeReadChapters()
        XCTAssertTrue(FileManager.default.fileExists(atPath: library.store.folder(doc.id).path))
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
        XCTAssertNotNil(library.error)
    }
    @MainActor func testRedownloadedChapterOverridesArchivedCopyAndUnreadRemainsLocal() throws {
        let (root, library, doc) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        library.removeReadChapters()
        var new = doc; new.id = UUID(); new.readComplete = false; new.localRemoved = nil
        try library.store.save(new); library.update(new)
        XCTAssertEqual(library.allDocuments.count, 1)
        XCTAssertEqual(library.allDocuments.first?.id, new.id)
        library.removeReadChapters()
        XCTAssertEqual(library.documents.count, 1)
    }
    @MainActor func testActualCBZReimportRestoresReadHistoryWithoutOpeningReader() async throws {
        let (root, library, doc) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        library.removeReadChapters()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 150)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 100, height: 150))
        }
        let data = try XCTUnwrap(image.pngData()), cbz = root.appendingPathComponent("reimport.cbz")
        let archive = try Archive(url: cbz, accessMode: .create)
        try archive.addEntry(with: "001.png", type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate) { offset, size in
            data.subdata(in: Int(offset)..<Int(offset) + size)
        }
        await library.importCBZ(cbz, remoteArtifactID: "replacement", origin: doc.origin, openWhenComplete: false)?.value
        XCTAssertNil(library.error)
        XCTAssertEqual(library.allDocuments.count, 1)
        let imported = try XCTUnwrap(library.documents.first)
        XCTAssertTrue(imported.hasLocalFiles)
        XCTAssertTrue(imported.complete)
        XCTAssertEqual(imported.readComplete, true)
        XCTAssertEqual(imported.lastReadAt, doc.lastReadAt)
        XCTAssertEqual(imported.lastPanelID, "10-2")
        XCTAssertNil(library.selected)
    }
}
