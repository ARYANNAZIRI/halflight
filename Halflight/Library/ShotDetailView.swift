import AVKit
import SwiftUI

/// Full-screen review on the inner display. Swipe up saves to Photos, swipe down asks to delete.
struct ShotDetailView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let item: MediaItem
    var onDeleted: (@MainActor () -> Void)? = nil

    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var confirmDelete = false
    @State private var toast: String?
    @State private var alert: AlertItem?
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
                .offset(y: dragOffset * 0.3)
                .gesture(swipe)
            if let toast {
                VStack {
                    Spacer()
                    ToastView(text: toast).padding(.bottom, 90)
                }
            }
        }
        .animation(Theme.quick, value: toast)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                ShareLink(item: app.media.fileURL(for: item)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Spacer()
                Button {
                    Task { await save() }
                } label: {
                    Label(item.savedToPhotos ? "Saved" : "Save", systemImage: item.savedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down")
                }
                .disabled(item.savedToPhotos)
                Spacer()
                if item.isPhoto {
                    Button {
                        app.openInEditor(item)
                    } label: {
                        Label("Edit", systemImage: "slider.horizontal.3")
                    }
                    Spacer()
                }
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .toolbarBackground(Theme.chrome, for: .bottomBar, .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this shot?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteItem() }
        }
        .alert(alert?.title ?? "", isPresented: Binding(get: { alert != nil }, set: { if !$0 { alert = nil } }), presenting: alert) { _ in
            Button("OK") {}
        } message: { item in
            Text(item.message)
        }
        .task(id: item.id) {
            if item.isVideo {
                player = AVPlayer(url: app.media.fileURL(for: item))
            } else {
                let url = app.media.fileURL(for: item)
                image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                    guard let data = try? Data(contentsOf: url) else { return nil }
                    return UIImage(data: data)
                }.value
            }
        }
        .onDisappear { player?.pause() }
    }

    @ViewBuilder
    private var content: some View {
        if item.isVideo {
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .accessibilityLabel(Text("Video"))
            } else {
                ProgressView().tint(Theme.inkMuted)
            }
        } else if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityLabel(Text("Photo"))
        } else {
            ProgressView().tint(Theme.inkMuted)
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in dragOffset = value.translation.height }
            .onEnded { value in
                defer { withAnimation(Theme.snap) { dragOffset = 0 } }
                if value.translation.height < -110 {
                    Task { await save() }
                } else if value.translation.height > 110 {
                    confirmDelete = true
                }
            }
    }

    private func save() async {
        guard !item.savedToPhotos else { return }
        do {
            try await PhotoLibrarySaver.save(fileURL: app.media.fileURL(for: item), kind: item.kind)
            app.media.markSaved(item)
            toast = String(localized: "Saved to Photos")
            Haptics.success(enabled: app.settings.hapticsOn)
            try? await Task.sleep(for: .seconds(1.4))
            toast = nil
        } catch {
            alert = AlertItem(title: String(localized: "Couldn’t save"), message: error.localizedDescription)
        }
    }

    private func deleteItem() {
        player?.pause()
        app.media.delete(item)
        if app.editingItemID == item.id { app.editingItemID = nil }
        if let onDeleted { onDeleted() } else { dismiss() }
    }
}
