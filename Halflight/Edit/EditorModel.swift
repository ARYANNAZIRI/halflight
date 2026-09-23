import SwiftUI
import UIKit

/// Quick Edit state. Preview renders are downsampled and debounced; export renders full size.
@MainActor @Observable
final class EditorModel {
    enum Tool: String, CaseIterable, Identifiable {
        case crop, adjust, markup
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .crop: "Crop"
            case .adjust: "Adjust"
            case .markup: "Markup"
            }
        }
        var symbol: String {
            switch self {
            case .crop: "crop.rotate"
            case .adjust: "slider.horizontal.3"
            case .markup: "pencil.tip.crop.circle"
            }
        }
    }

    let item: MediaItem
    let store: MediaStore
    let saveOriginalToo: Bool

    var adjustments = ImageAdjustments()
    var strokes: [MarkupStroke] = []
    var tool: Tool = .adjust
    var markupKind: MarkupKind = .arrow
    /// Aspect preset for crop as width/height in unit space; nil = free.
    var cropAspect: CGFloat?
    var showOriginal = false
    var original: UIImage?
    var preview: UIImage?
    var isLoading = true
    var isExporting = false
    var toast: String?
    var alert: AlertItem?
    var shareURL: URL?

    @ObservationIgnored private var sourceData: Data?
    @ObservationIgnored private var renderTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init(item: MediaItem, store: MediaStore, saveOriginalToo: Bool) {
        self.item = item
        self.store = store
        self.saveOriginalToo = saveOriginalToo
    }

    var hasChanges: Bool { !adjustments.isIdentity || !strokes.isEmpty }

    /// Aspect of the image the overlays sit on.
    var previewAspect: CGFloat {
        guard let preview, preview.size.height > 0 else { return 3.0 / 4.0 }
        return preview.size.width / preview.size.height
    }

    func load() async {
        let url = store.fileURL(for: item)
        let data = await Task.detached(priority: .userInitiated) { try? Data(contentsOf: url) }.value
        sourceData = data
        guard let data else {
            isLoading = false
            alert = AlertItem(title: String(localized: "Couldn’t open"), message: String(localized: "The file is missing."))
            return
        }
        let base = await Task.detached(priority: .userInitiated) {
            ImageAdjust.render(data: data, adjustments: ImageAdjustments(), maxPixel: 2048)
        }.value
        original = base
        preview = base
        isLoading = false
    }

    /// Debounced preview render. Call after any adjustment change.
    func adjustmentsChanged() {
        renderTask?.cancel()
        guard let data = sourceData else { return }
        let adjustments = self.adjustments
        renderTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            if Task.isCancelled { return }
            let rendered = await Task.detached(priority: .userInitiated) {
                ImageAdjust.render(data: data, adjustments: adjustments, maxPixel: 2048)
            }.value
            if Task.isCancelled { return }
            self?.preview = rendered
        }
    }

    func rotate() {
        adjustments.quarterTurns = (adjustments.quarterTurns + 1) % 4
        clearStrokesIfNeeded()
        adjustmentsChanged()
    }

    func setCropAspect(_ aspect: CGFloat?) {
        cropAspect = aspect
        guard let aspect, let original else { return }
        // Fit the largest centred rect of the requested aspect inside the un-rotated image.
        let imageAspect = original.size.width / original.size.height
        var rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        if aspect > imageAspect {
            rect.size.height = imageAspect / aspect
            rect.origin.y = (1 - rect.height) / 2
        } else {
            rect.size.width = aspect / imageAspect
            rect.origin.x = (1 - rect.width) / 2
        }
        adjustments.crop = rect
        clearStrokesIfNeeded()
        adjustmentsChanged()
    }

    func resetCrop() {
        adjustments.crop = CGRect(x: 0, y: 0, width: 1, height: 1)
        adjustments.quarterTurns = 0
        cropAspect = nil
        adjustmentsChanged()
    }

    func resetAdjustments() {
        adjustments.exposure = 0
        adjustments.contrast = 1
        adjustments.warmth = 0
        adjustmentsChanged()
    }

    func undoStroke() {
        _ = strokes.popLast()
    }

    func clearStrokes() {
        strokes.removeAll()
    }

    private func clearStrokesIfNeeded() {
        guard !strokes.isEmpty else { return }
        strokes.removeAll()
        showToast(String(localized: "Markup cleared"))
    }

    // MARK: Export

    /// Full-resolution adjusted image with markup burned in.
    func exportImage() async -> UIImage? {
        guard let data = sourceData else { return nil }
        let adjustments = self.adjustments
        let strokes = self.strokes
        return await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let base = ImageAdjust.render(data: data, adjustments: adjustments, maxPixel: nil) else { return nil }
            return ImageAdjust.composite(base, strokes: strokes)
        }.value
    }

    func saveToRoll() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }
        guard let image = await exportImage(), let encoded = ImageAdjust.encode(image) else {
            alert = AlertItem(title: String(localized: "Couldn’t export"), message: String(localized: "The edit couldn’t be rendered."))
            return
        }
        do {
            let saved = try await store.addPhoto(data: encoded, sessionID: item.sessionID, editedFrom: item.id)
            if !saveOriginalToo { store.delete(item) }
            showToast(String(localized: "Saved to Roll"))
            EventLog.log("photo_saved", ["id": saved.id.uuidString, "edited": "1"])
        } catch {
            alert = AlertItem(title: String(localized: "Couldn’t save"), message: error.localizedDescription)
        }
    }

    func saveToPhotos() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }
        guard let url = await writeTemporaryExport() else { return }
        do {
            try await PhotoLibrarySaver.save(fileURL: url, kind: .photo)
            showToast(String(localized: "Saved to Photos"))
        } catch {
            alert = AlertItem(title: String(localized: "Couldn’t save"), message: error.localizedDescription)
        }
    }

    func copyToPasteboard() async {
        guard let image = await exportImage() else { return }
        UIPasteboard.general.image = image
        showToast(String(localized: "Copied"))
    }

    func prepareShare() async {
        shareURL = await writeTemporaryExport()
    }

    private func writeTemporaryExport() async -> URL? {
        guard let image = await exportImage(), let encoded = ImageAdjust.encode(image) else {
            alert = AlertItem(title: String(localized: "Couldn’t export"), message: String(localized: "The edit couldn’t be rendered."))
            return nil
        }
        let isHEIF = MediaStore.isHEIF(encoded)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Halflight-\(UUID().uuidString).\(isHEIF ? "heic" : "jpg")")
        do {
            try await Task.detached(priority: .userInitiated) { try encoded.write(to: url, options: .atomic) }.value
            return url
        } catch {
            alert = AlertItem(title: String(localized: "Couldn’t export"), message: error.localizedDescription)
            return nil
        }
    }

    func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}
