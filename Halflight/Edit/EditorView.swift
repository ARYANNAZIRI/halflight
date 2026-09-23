import AVKit
import SwiftUI
import UIKit

/// Quick Edit. Open Duo: the full 7.6-inch canvas. Closed: a standard editor. Never letterboxed.
struct EditorView: View {
    @Environment(AppState.self) private var app
    let item: MediaItem
    @State private var model: EditorModel?

    var body: some View {
        Group {
            if item.isVideo {
                VideoReviewView(item: item)
            } else if let model {
                EditorContent(model: model)
            } else {
                ProgressView().tint(Theme.inkMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .chromeBackground()
            }
        }
        .task(id: item.id) {
            guard item.isPhoto else { return }
            let editor = EditorModel(item: item, store: app.media, saveOriginalToo: app.settings.saveOriginalAndEdit)
            model = editor
            await editor.load()
        }
    }
}

struct EditorContent: View {
    @Bindable var model: EditorModel
    @State private var showShare = false

    var body: some View {
        VStack(spacing: 0) {
            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)

            toolPanel
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            HStack(spacing: 10) {
                ForEach(EditorModel.Tool.allCases) { tool in
                    ChromeChip(text: tool.title, symbol: tool.symbol, active: model.tool == tool) {
                        withAnimation(Theme.quick) { model.tool = tool }
                    }
                }
                Spacer()
                beforeAfter
                exportMenu
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .chromeBackground()
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(text: toast).padding(.bottom, 120)
            }
        }
        .animation(Theme.quick, value: model.toast)
        .alert(model.alert?.title ?? "", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } }), presenting: model.alert) { _ in
            Button("OK") {}
        } message: { item in
            Text(item.message)
        }
        .sheet(isPresented: $showShare, onDismiss: { model.shareURL = nil }) {
            if let url = model.shareURL {
                ActivityView(items: [url])
                    .presentationDetents([.medium, .large])
            }
        }
        .onChange(of: model.shareURL) { _, url in
            showShare = url != nil
        }
    }

    // MARK: Canvas

    private var canvas: some View {
        ZStack {
            if model.isLoading {
                ProgressView().tint(Theme.inkMuted)
            } else if let image = model.showOriginal ? model.original : model.preview {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                    if model.tool == .markup, !model.showOriginal {
                        MarkupCanvas(model: model, enabled: true)
                    } else if !model.strokes.isEmpty, !model.showOriginal {
                        MarkupCanvas(model: model, enabled: false)
                    }
                    if model.tool == .crop, !model.showOriginal, model.adjustments.quarterTurns % 4 == 0 {
                        CropOverlay(crop: Binding(
                            get: { model.adjustments.crop },
                            set: { model.adjustments.crop = $0; model.adjustmentsChanged() }
                        ), aspect: cropAspectInUnitSpace)
                    }
                }
                .aspectRatio(model.previewAspect, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
            } else {
                EmptyPaneView(symbol: "photo", title: "Couldn’t open", detail: "This photo couldn’t be loaded.")
            }
        }
        .accessibilityLabel(model.showOriginal ? Text("Original photo") : Text("Edited photo"))
    }

    /// The crop overlay works in unit space of the un-rotated image, so convert the preset
    /// (width/height in pixels) into unit width/height.
    private var cropAspectInUnitSpace: CGFloat? {
        guard let aspect = model.cropAspect, let original = model.original, original.size.height > 0 else { return nil }
        let imageAspect = original.size.width / original.size.height
        return aspect / imageAspect
    }

    // MARK: Tool panels

    @ViewBuilder
    private var toolPanel: some View {
        switch model.tool {
        case .crop:
            HStack(spacing: 8) {
                ChromeButton(symbol: "rotate.right", label: "Rotate") { model.rotate() }
                ChromeChip(text: "Free", active: model.cropAspect == nil) { model.setCropAspect(nil) }
                ChromeChip(text: "1:1", active: model.cropAspect == 1) { model.setCropAspect(1) }
                ChromeChip(text: "4:3", active: model.cropAspect == 4.0 / 3.0) { model.setCropAspect(4.0 / 3.0) }
                ChromeChip(text: "16:9", active: model.cropAspect == 16.0 / 9.0) { model.setCropAspect(16.0 / 9.0) }
                Spacer()
                ChromeChip(text: "Reset", active: false) { model.resetCrop() }
                    .disabled(!model.adjustments.isCropped)
            }
            .frame(height: 44)
        case .adjust:
            VStack(spacing: 6) {
                AdjustSlider(title: "Exposure", value: Binding(get: { model.adjustments.exposure }, set: { model.adjustments.exposure = $0; model.adjustmentsChanged() }), range: -2...2)
                AdjustSlider(title: "Contrast", value: Binding(get: { model.adjustments.contrast }, set: { model.adjustments.contrast = $0; model.adjustmentsChanged() }), range: 0.5...1.5)
                AdjustSlider(title: "Warmth", value: Binding(get: { model.adjustments.warmth }, set: { model.adjustments.warmth = $0; model.adjustmentsChanged() }), range: -1...1)
                HStack {
                    Spacer()
                    Button("Reset") { model.resetAdjustments() }
                        .font(.footnote)
                        .disabled(model.adjustments.exposure == 0 && model.adjustments.contrast == 1 && model.adjustments.warmth == 0)
                }
            }
        case .markup:
            HStack(spacing: 8) {
                ForEach(MarkupKind.allCases) { kind in
                    ChromeButton(symbol: kind.symbol, label: kind.title, active: model.markupKind == kind) {
                        model.markupKind = kind
                    }
                }
                Spacer()
                ChromeButton(symbol: "arrow.uturn.backward", label: "Undo") { model.undoStroke() }
                    .disabled(model.strokes.isEmpty)
                ChromeChip(text: "Clear", active: false) { model.clearStrokes() }
                    .disabled(model.strokes.isEmpty)
            }
            .frame(height: 44)
        }
    }

    private var beforeAfter: some View {
        Image(systemName: "rectangle.lefthalf.filled")
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(model.showOriginal ? Theme.amber : Theme.ink)
            .frame(width: 44, height: 44)
            .background(Circle().fill(Theme.chromeRaised.opacity(0.85)))
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: 0.05, maximumDistance: 30) {
                // Release handled by onPressingChanged.
            } onPressingChanged: { pressing in
                model.showOriginal = pressing
            }
            .disabled(!model.hasChanges)
            .opacity(model.hasChanges ? 1 : 0.4)
            .accessibilityLabel(Text("Before and after"))
            .accessibilityHint(Text("Hold to see the original."))
    }

    private var exportMenu: some View {
        Menu {
            Button {
                Task { await model.saveToRoll() }
            } label: {
                Label("Save to Roll", systemImage: "square.and.arrow.down.on.square")
            }
            Button {
                Task { await model.saveToPhotos() }
            } label: {
                Label("Save to Photos", systemImage: "photo.badge.plus")
            }
            Button {
                Task { await model.prepareShare() }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button {
                Task { await model.copyToPasteboard() }
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        } label: {
            HStack(spacing: 6) {
                if model.isExporting { ProgressView().tint(Theme.chrome).controlSize(.small) }
                Text("Export").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.chrome)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Capsule().fill(Theme.amber))
        }
        .disabled(model.isLoading || model.isExporting)
        .accessibilityLabel(Text("Export"))
    }
}

struct AdjustSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.inkMuted)
                .frame(width: 72, alignment: .leading)
            Slider(value: $value, in: range)
                .tint(Theme.amber)
                .accessibilityLabel(Text(title))
            Text(value, format: .number.precision(.fractionLength(2)))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Theme.inkFaint)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

/// Videos: review and export in v1. Trimming comes later.
struct VideoReviewView: View {
    @Environment(AppState.self) private var app
    let item: MediaItem
    @State private var player: AVPlayer?
    @State private var toast: String?

    var body: some View {
        VStack(spacing: 12) {
            if let player {
                VideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
            } else {
                ProgressView().tint(Theme.inkMuted)
            }
            HStack(spacing: 10) {
                ShareLink(item: app.media.fileURL(for: item)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                Button {
                    Task {
                        do {
                            try await PhotoLibrarySaver.save(fileURL: app.media.fileURL(for: item), kind: .video)
                            app.media.markSaved(item)
                            toast = String(localized: "Saved to Photos")
                        } catch {
                            app.capture.alert = AlertItem(title: String(localized: "Couldn’t save"), message: error.localizedDescription)
                        }
                    }
                } label: {
                    Label("Save to Photos", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(item.savedToPhotos)
                Spacer()
                Text("Video trimming comes later.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .padding(16)
        .chromeBackground()
        .overlay(alignment: .bottom) {
            if let toast { ToastView(text: toast).padding(.bottom, 80) }
        }
        .task(id: item.id) {
            player = AVPlayer(url: app.media.fileURL(for: item))
        }
        .onChange(of: toast) { _, value in
            guard value != nil else { return }
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                toast = nil
            }
        }
        .onDisappear { player?.pause() }
    }
}

/// The Edit tab: whatever Roll last handed over, or an empty state.
struct EditTabView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        if let item = app.media.item(id: app.editingItemID) {
            NavigationStack {
                EditorView(item: item)
                    .navigationTitle("Edit")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(Theme.chrome, for: .navigationBar)
            }
        } else {
            EmptyPaneView(symbol: "slider.horizontal.3", title: "Nothing to edit yet", detail: "Pick a photo in Roll and choose Edit.")
                .overlay(alignment: .bottom) {
                    Button("Open Roll") { app.tab = .roll }
                        .buttonStyle(.bordered)
                        .padding(.bottom, 40)
                }
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
