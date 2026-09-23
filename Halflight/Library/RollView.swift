import SwiftUI

enum RollFilter: String, CaseIterable, Identifiable {
    case all, photos, videos, saved

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .all: "All"
        case .photos: "Photos"
        case .videos: "Videos"
        case .saved: "Saved"
        }
    }

    func matches(_ item: MediaItem) -> Bool {
        switch self {
        case .all: true
        case .photos: item.isPhoto
        case .videos: item.isVideo
        case .saved: item.savedToPhotos
        }
    }
}

/// Compact: grid → full-screen shot. Regular (open Duo, Split View): Roll on one half, Edit on the other.
struct RollView: View {
    @Environment(AppState.self) private var app
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var filter: RollFilter = .all
    @State private var opened: MediaItem?
    @State private var selection: MediaItem.ID?

    var body: some View {
        if hSize == .regular {
            NavigationSplitView {
                RollGridView(filter: $filter, selectedID: selection) { item in
                    selection = item.id
                }
                .navigationTitle("Roll")
                .toolbarBackground(Theme.chrome, for: .navigationBar)
            } detail: {
                if let item = app.media.item(id: selection) {
                    ShotDetailView(item: item, onDeleted: { selection = nil })
                        .id(item.id)
                } else {
                    EmptyPaneView(symbol: "photo.on.rectangle.angled", title: "Pick a shot", detail: "Open a shot from the Roll to review, save, or edit it here.")
                }
            }
            .navigationSplitViewStyle(.balanced)
            .chromeBackground()
        } else {
            NavigationStack {
                RollGridView(filter: $filter, selectedID: nil) { item in
                    opened = item
                }
                .navigationTitle("Roll")
                .navigationDestination(item: $opened) { item in
                    ShotDetailView(item: item, onDeleted: { opened = nil })
                }
            }
        }
    }
}

private struct SessionGroup: Identifiable {
    let id: UUID
    let date: Date
    let items: [MediaItem]
}

struct RollGridView: View {
    @Environment(AppState.self) private var app
    @Binding var filter: RollFilter
    let selectedID: MediaItem.ID?
    let onOpen: @MainActor (MediaItem) -> Void

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: 3)]

    var body: some View {
        let sessions = app.media.sessions
            .map { session in SessionGroup(id: session.id, date: session.date, items: session.items.filter(filter.matches)) }
            .filter { !$0.items.isEmpty }

        ScrollView {
            if sessions.isEmpty {
                EmptyRollView(filter: filter)
                    .padding(.top, 80)
            } else {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(sessions) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.date, format: .dateTime.weekday(.wide).day().month().hour().minute())
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.inkMuted)
                                .padding(.horizontal, 12)
                            LazyVGrid(columns: columns, spacing: 3) {
                                ForEach(entry.items) { item in
                                    ThumbCell(item: item, selected: item.id == selectedID)
                                        .onTapGesture { onOpen(item) }
                                        .contextMenu { ShotActions(item: item) }
                                }
                            }
                            .padding(.horizontal, 3)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .chromeBackground()
        .safeAreaInset(edge: .top) {
            Picker("Filter", selection: $filter) {
                ForEach(RollFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.chrome)
        }
    }
}

struct ThumbCell: View {
    @Environment(AppState.self) private var app
    let item: MediaItem
    var selected = false
    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(Theme.chromeRaised)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 4) {
                    if item.savedToPhotos {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 11))
                    }
                    if item.isVideo, let duration = item.duration {
                        Text(RecordingBadge.format(Int(duration)))
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    }
                }
                .foregroundStyle(Theme.ink)
                .padding(6)
                .shadow(radius: 3)
            }
            .overlay(Rectangle().stroke(selected ? Theme.amber : .clear, lineWidth: 2))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.isVideo ? Text("Video") : Text("Photo"))
        .accessibilityValue(Text(item.createdAt, style: .time))
        .task(id: item.id) {
            image = await app.media.thumbnail(for: item)
        }
    }
}

struct ShotActions: View {
    @Environment(AppState.self) private var app
    let item: MediaItem

    var body: some View {
        Button {
            Task { await save() }
        } label: {
            Label("Save to Photos", systemImage: "square.and.arrow.down")
        }
        if item.isPhoto {
            Button {
                app.openInEditor(item)
            } label: {
                Label("Edit", systemImage: "slider.horizontal.3")
            }
        }
        Button(role: .destructive) {
            app.media.delete(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func save() async {
        do {
            try await PhotoLibrarySaver.save(fileURL: app.media.fileURL(for: item), kind: item.kind)
            app.media.markSaved(item)
        } catch {
            app.capture.alert = AlertItem(title: String(localized: "Couldn’t save"), message: error.localizedDescription)
        }
    }
}

struct EmptyRollView: View {
    let filter: RollFilter

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Theme.inkMuted)
            Text(filter == .all ? "Nothing here yet" : "Nothing matches this filter")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("Shots you take land here. Nothing leaves the phone unless you share it.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

struct EmptyPaneView: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Theme.inkMuted)
            Text(title).font(.headline).foregroundStyle(Theme.ink)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .chromeBackground()
    }
}
