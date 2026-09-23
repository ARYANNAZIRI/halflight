import AVFoundation
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum MediaStoreError: LocalizedError {
    case writeFailed
    case missingFile

    var errorDescription: String? {
        switch self {
        case .writeFailed: String(localized: "The file couldn’t be written.")
        case .missingFile: String(localized: "The file is missing.")
        }
    }
}

/// Local library. Metadata lives in a JSON index; bytes live in Documents. Nothing is uploaded.
@MainActor @Observable
final class MediaStore {
    private(set) var items: [MediaItem] = []
    let paths: MediaPaths

    @ObservationIgnored private let thumbCache = NSCache<NSString, UIImage>()

    init(paths: MediaPaths = .standard()) {
        self.paths = paths
        paths.createDirectories()
        load()
    }

    // MARK: Paths

    func fileURL(for item: MediaItem) -> URL {
        paths.media.appendingPathComponent(item.fileName)
    }

    func thumbURL(for item: MediaItem) -> URL {
        paths.thumbs.appendingPathComponent(item.thumbName)
    }

    /// Where the next video recording should be written. Registered with `addVideo` once it finishes.
    func newVideoURL() -> URL {
        paths.media.appendingPathComponent("\(UUID().uuidString).mov")
    }

    // MARK: Queries

    func item(id: MediaItem.ID?) -> MediaItem? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    struct Session: Identifiable, Hashable, Sendable {
        let id: UUID
        let date: Date
        let items: [MediaItem]
    }

    /// One session = one story. Newest first.
    var sessions: [Session] {
        let grouped = Dictionary(grouping: items, by: \.sessionID)
        return grouped.map { key, value in
            let sorted = value.sorted { $0.createdAt > $1.createdAt }
            return Session(id: key, date: sorted.first?.createdAt ?? .distantPast, items: sorted)
        }
        .sorted { $0.date > $1.date }
    }

    // MARK: Add

    func addPhoto(data: Data, sessionID: UUID, editedFrom: UUID? = nil) async throws -> MediaItem {
        let id = UUID()
        let isHEIF = Self.isHEIF(data)
        let fileName = "\(id.uuidString).\(isHEIF ? "heic" : "jpg")"
        let thumbName = "\(id.uuidString).jpg"
        let fileURL = paths.media.appendingPathComponent(fileName)
        let thumbURL = paths.thumbs.appendingPathComponent(thumbName)

        let size = try await Task.detached(priority: .userInitiated) {
            try data.write(to: fileURL, options: .atomic)
            let thumb = Self.makeImageThumbnail(at: fileURL, maxPixel: 640)
            if let thumb, let jpeg = UIImage(cgImage: thumb).jpegData(compressionQuality: 0.82) {
                try? jpeg.write(to: thumbURL, options: .atomic)
            }
            return Self.imageSize(at: fileURL)
        }.value

        var item = MediaItem(
            id: id, kind: .photo, createdAt: .now, sessionID: sessionID,
            fileName: fileName, thumbName: thumbName
        )
        item.pixelWidth = size.map { Int($0.width) }
        item.pixelHeight = size.map { Int($0.height) }
        item.editedFrom = editedFrom
        items.insert(item, at: 0)
        persist()
        return item
    }

    func addVideo(at url: URL, sessionID: UUID) async throws -> MediaItem {
        guard FileManager.default.fileExists(atPath: url.path) else { throw MediaStoreError.missingFile }
        let id = UUID()
        let fileName = "\(id.uuidString).mov"
        let thumbName = "\(id.uuidString).jpg"
        let destination = paths.media.appendingPathComponent(fileName)
        let thumbURL = paths.thumbs.appendingPathComponent(thumbName)

        let info = try await Task.detached(priority: .userInitiated) { () async throws -> (Double, CGSize?) in
            if url != destination {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: url, to: destination)
            }
            let asset = AVURLAsset(url: destination)
            let duration = (try? await asset.load(.duration)).map { $0.seconds } ?? 0
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 640, height: 640)
            var size: CGSize?
            if let result = try? await generator.image(at: CMTime(seconds: min(0.5, max(0, duration / 2)), preferredTimescale: 600)) {
                let image = UIImage(cgImage: result.image)
                if let jpeg = image.jpegData(compressionQuality: 0.82) {
                    try? jpeg.write(to: thumbURL, options: .atomic)
                }
            }
            if let track = try? await asset.loadTracks(withMediaType: .video).first,
               let natural = try? await track.load(.naturalSize) {
                size = natural
            }
            return (duration, size)
        }.value

        var item = MediaItem(
            id: id, kind: .video, createdAt: .now, sessionID: sessionID,
            fileName: fileName, thumbName: thumbName
        )
        item.duration = info.0
        item.pixelWidth = info.1.map { Int($0.width) }
        item.pixelHeight = info.1.map { Int($0.height) }
        items.insert(item, at: 0)
        persist()
        return item
    }

    // MARK: Mutate

    func delete(_ item: MediaItem) {
        items.removeAll { $0.id == item.id }
        thumbCache.removeObject(forKey: item.id.uuidString as NSString)
        let file = fileURL(for: item)
        let thumb = thumbURL(for: item)
        Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: file)
            try? FileManager.default.removeItem(at: thumb)
        }
        persist()
    }

    func markSaved(_ item: MediaItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].savedToPhotos = true
        persist()
    }

    func deleteAll() {
        for item in items { delete(item) }
    }

    // MARK: Thumbnails

    func cachedThumbnail(for item: MediaItem) -> UIImage? {
        thumbCache.object(forKey: item.id.uuidString as NSString)
    }

    func thumbnail(for item: MediaItem) async -> UIImage? {
        if let cached = cachedThumbnail(for: item) { return cached }
        let url = thumbURL(for: item)
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
        if let image { thumbCache.setObject(image, forKey: item.id.uuidString as NSString) }
        return image
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: paths.index) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([MediaItem].self, from: data) {
            let fm = FileManager.default
            items = decoded.filter { fm.fileExists(atPath: paths.media.appendingPathComponent($0.fileName).path) }
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: paths.index, options: .atomic)
    }

    // MARK: Helpers (off-main)

    nonisolated static func isHEIF(_ data: Data) -> Bool {
        guard data.count > 12 else { return false }
        let brand = data.subdata(in: 4..<12)
        return brand.starts(with: Array("ftyp".utf8)) && (brand.suffix(4) == Data("heic".utf8) || brand.suffix(4) == Data("heix".utf8) || brand.suffix(4) == Data("mif1".utf8))
    }

    nonisolated static func makeImageThumbnail(at url: URL, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    nonisolated static func imageSize(at url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: width, height: height)
    }
}
