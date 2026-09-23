import Foundation

struct MediaItem: Codable, Identifiable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case photo, video
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date
    /// Groups shots into a story: one capture session, one section in Roll.
    let sessionID: UUID
    let fileName: String
    let thumbName: String
    var duration: Double?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var savedToPhotos = false
    var editedFrom: UUID?

    var isPhoto: Bool { kind == .photo }
    var isVideo: Bool { kind == .video }
}

/// On-disk layout:
///   Documents/Media/{uuid}.heic | .mov
///   Documents/Thumbs/{uuid}.jpg
///   Documents/Scripts/{uuid}.txt
///   Library/Application Support/halflight-index.json
struct MediaPaths: Sendable {
    let media: URL
    let thumbs: URL
    let scripts: URL
    let index: URL

    static func standard() -> MediaPaths {
        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? documents
        return MediaPaths(
            media: documents.appendingPathComponent("Media", isDirectory: true),
            thumbs: documents.appendingPathComponent("Thumbs", isDirectory: true),
            scripts: documents.appendingPathComponent("Scripts", isDirectory: true),
            index: support.appendingPathComponent("halflight-index.json")
        )
    }

    static func temporary() -> MediaPaths {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("halflight-\(UUID().uuidString)", isDirectory: true)
        return MediaPaths(
            media: root.appendingPathComponent("Media", isDirectory: true),
            thumbs: root.appendingPathComponent("Thumbs", isDirectory: true),
            scripts: root.appendingPathComponent("Scripts", isDirectory: true),
            index: root.appendingPathComponent("index.json")
        )
    }

    func createDirectories() {
        let fm = FileManager.default
        for url in [media, thumbs, scripts, index.deletingLastPathComponent()] {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
