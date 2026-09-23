import Foundation
import Photos

enum PhotoLibraryError: LocalizedError {
    case denied

    var errorDescription: String? {
        switch self {
        case .denied: String(localized: "Photos access is off. You can allow adding photos in Settings.")
        }
    }
}

enum PhotoLibrarySaver {
    /// Saves a file already on disk. Asks for add-only permission only when needed.
    static func save(fileURL: URL, kind: MediaItem.Kind) async throws {
        guard await Permissions.photosAddOnly() else { throw PhotoLibraryError.denied }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false
            switch kind {
            case .photo: request.addResource(with: .photo, fileURL: fileURL, options: options)
            case .video: request.addResource(with: .video, fileURL: fileURL, options: options)
            }
        }
    }
}
