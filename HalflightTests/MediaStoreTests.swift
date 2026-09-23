import Foundation
import Testing
import UIKit
@testable import Halflight

@MainActor
struct MediaStoreTests {
    private func sampleJPEG() -> Data {
        // Scale 1 so pixel dimensions match points regardless of the simulator's screen scale.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 48), format: format)
        let image = renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }

    @Test func addPhotoWritesFileAndThumb() async throws {
        let paths = MediaPaths.temporary()
        let store = MediaStore(paths: paths)
        let session = UUID()

        let item = try await store.addPhoto(data: sampleJPEG(), sessionID: session)

        #expect(store.items.count == 1)
        #expect(item.kind == .photo)
        #expect(item.sessionID == session)
        #expect(item.pixelWidth == 64)
        #expect(item.pixelHeight == 48)
        #expect(FileManager.default.fileExists(atPath: store.fileURL(for: item).path))
        #expect(FileManager.default.fileExists(atPath: store.thumbURL(for: item).path))
        let thumb = await store.thumbnail(for: item)
        #expect(thumb != nil)
    }

    @Test func indexSurvivesReload() async throws {
        let paths = MediaPaths.temporary()
        let first = MediaStore(paths: paths)
        let item = try await first.addPhoto(data: sampleJPEG(), sessionID: UUID())
        first.markSaved(item)

        let second = MediaStore(paths: paths)
        #expect(second.items.count == 1)
        #expect(second.items.first?.id == item.id)
        #expect(second.items.first?.savedToPhotos == true)
    }

    @Test func deleteRemovesFiles() async throws {
        let paths = MediaPaths.temporary()
        let store = MediaStore(paths: paths)
        let item = try await store.addPhoto(data: sampleJPEG(), sessionID: UUID())
        let file = store.fileURL(for: item)

        store.delete(item)
        #expect(store.items.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func sessionsGroupNewestFirst() async throws {
        let store = MediaStore(paths: .temporary())
        let older = UUID()
        let newer = UUID()
        _ = try await store.addPhoto(data: sampleJPEG(), sessionID: older)
        try await Task.sleep(for: .milliseconds(20))
        _ = try await store.addPhoto(data: sampleJPEG(), sessionID: newer)

        let sessions = store.sessions
        #expect(sessions.count == 2)
        #expect(sessions.first?.id == newer)
    }

    @Test func heifSniffing() {
        var data = Data(count: 4)
        data.append(contentsOf: Array("ftypheic".utf8))
        data.append(Data(count: 8))
        #expect(MediaStore.isHEIF(data))
        #expect(!MediaStore.isHEIF(sampleJPEG()))
    }
}
