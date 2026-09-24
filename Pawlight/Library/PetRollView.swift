import SwiftUI

/// Grid of every shot, newest first. Uses Halflight's `MediaStore`, so files stay on the phone
/// until the user saves or shares them.
struct PetRollView: View {
    @Environment(PawState.self) private var app
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        NavigationStack {
            Group {
                if app.media.items.isEmpty {
                    ContentUnavailableView(
                        "No shots yet",
                        systemImage: "pawprint",
                        description: Text("Turn on Catch, play a sound, and Pawlight takes the photo when your pet looks up.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(app.media.items) { item in
                                NavigationLink(value: item) {
                                    RollCell(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Roll")
            .navigationDestination(for: MediaItem.self) { item in
                PetShotView(item: item)
            }
            .background(Theme.chrome)
            .toolbarBackground(Theme.chrome, for: .navigationBar)
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: hSize == .regular ? 5 : 3)
    }
}

private struct RollCell: View {
    @Environment(PawState.self) private var app
    let item: MediaItem
    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(Theme.chromeRaised)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if item.savedToPhotos {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.treat)
                        .padding(4)
                }
            }
            .task(id: item.id) {
                image = app.media.cachedThumbnail(for: item)
                if image == nil { image = await app.media.thumbnail(for: item) }
            }
            .accessibilityLabel(Text("Photo"))
    }
}

/// One shot, full size, with Save, Share and Delete.
struct PetShotView: View {
    @Environment(PawState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let item: MediaItem
    @State private var image: UIImage?
    @State private var confirmDelete = false
    @State private var message: String?

    var body: some View {
        let url = app.media.fileURL(for: item)
        ZStack {
            Color.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView().tint(Theme.inkMuted)
            }
            if let message {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.black.opacity(0.7)))
                        .padding(.bottom, 24)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    Task { await save(url) }
                } label: {
                    Label("Save to Photos", systemImage: "square.and.arrow.down")
                }
                Spacer()
                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Spacer()
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .toolbarBackground(Theme.chrome, for: .bottomBar, .navigationBar)
        .confirmationDialog("Delete this photo?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                app.media.delete(item)
                dismiss()
            }
        }
        .task(id: item.id) {
            image = await Task.detached(priority: .userInitiated) {
                UIImage(contentsOfFile: url.path)
            }.value
        }
    }

    private func save(_ url: URL) async {
        do {
            try await PhotoLibrarySaver.save(fileURL: url, kind: .photo)
            app.media.markSaved(item)
            flash(String(localized: "Saved to Photos"))
        } catch {
            flash(error.localizedDescription)
        }
    }

    private func flash(_ text: String) {
        message = text
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            message = nil
        }
    }
}
