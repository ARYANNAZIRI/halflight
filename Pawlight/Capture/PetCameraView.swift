import SwiftUI

/// Picks the layout by size class (never by UIDevice.orientation) and registers the Duo hooks.
struct PetCameraView: View {
    @Environment(PawState.self) private var app
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        let model = app.camera
        Group {
            if hSize == .regular {
                PetCameraOpenView(model: model, openRoll: { app.tab = .roll })
            } else {
                PetCameraClosedView(model: model, openRoll: { app.tab = .roll })
            }
        }
        .chromeBackground()
        .background(CaptureEventHost(onPrimary: { model.shutterTapped() }))
        .hingeReporting(app.hinge)
        .lureAccessory(model: model, hinge: app.hinge)
        .task {
            await model.start()
        }
        .onDisappear {
            model.scheduleRelease()
        }
        .sheet(isPresented: Binding(get: { model.showPaywall }, set: { model.showPaywall = $0 })) {
            ProPaywallView()
        }
        .alert(
            model.alert?.title ?? "",
            isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } }),
            presenting: model.alert
        ) { _ in
            Button("OK") {}
        } message: { item in
            Text(item.message)
        }
    }
}

/// Compact width: closed Duo (outer display) and every other iPhone.
struct PetCameraClosedView: View {
    let model: PetCameraModel
    let openRoll: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if model.isDuo, model.lens != .front, model.hinge.posture != .closed {
                    LurePill(model: model)
                }
                Spacer()
                CatchToggle(model: model)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)

            PetViewfinder(model: model)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)

            if model.lureIsLive {
                LureStrip(model: model)
                    .padding(.top, 10)
            }

            SoundPad(model: model, columns: 6)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            Spacer(minLength: 8)

            ZoomChips(model: model)
                .padding(.bottom, 12)

            HStack {
                LastShotThumb(model: model, action: openRoll)
                Spacer()
                PetShutterButton(model: model)
                Spacer()
                FlipButton(model: model)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
        .animation(Theme.snap, value: model.lureIsLive)
    }
}

/// Regular width: open Duo (inner display). Viewfinder plus a tools column on the outer edge,
/// so nothing interactive sits over the crease and thumbs reach it in 50/50 Split View.
struct PetCameraOpenView: View {
    let model: PetCameraModel
    let openRoll: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                PetViewfinder(model: model)
                    .padding(12)
                    .creaseAvoiding(model.hinge.posture)
                CreaseGuide(posture: model.hinge.posture)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ScrollView {
                VStack(spacing: 12) {
                    if model.isDuo, model.lens != .front {
                        LurePill(model: model)
                    }
                    if model.lureIsLive {
                        LureStrip(model: model, vertical: true)
                    }
                    CatchToggle(model: model)
                    SoundPad(model: model, columns: 2)
                    ZoomChips(model: model, vertical: true)
                }
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    PetShutterButton(model: model)
                    HStack(spacing: 16) {
                        LastShotThumb(model: model, action: openRoll)
                        FlipButton(model: model)
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Theme.chrome)
            }
            .frame(width: 140)
            .frame(maxHeight: .infinity)
            .background(Theme.chrome)
        }
        .animation(Theme.snap, value: model.lureIsLive)
    }
}

// MARK: - Viewfinder

struct PetViewfinder: View {
    let model: PetCameraModel

    var body: some View {
        ZStack {
            switch model.status {
            case .unauthorized:
                CameraMessage(
                    symbol: "camera.fill",
                    title: "Camera access is off",
                    message: "Allow camera access in Settings to take pet photos.",
                    button: "Open Settings",
                    action: { Permissions.openSystemSettings() }
                )
            case .failed(let message):
                CameraMessage(symbol: "exclamationmark.triangle", title: "The camera stopped", verbatim: message,
                              button: "Try again", action: { model.retry() })
            default:
                if let source = model.previewSource {
                    CameraPreviewView(
                        source: source,
                        onTap: { _, devicePoint in model.focus(devicePoint: devicePoint) },
                        onDirectionsChange: { model.directionsChanged($0) }
                    )
                } else {
                    Color.black
                }
            }

            VStack {
                LookBadge(model: model)
                    .padding(.top, 12)
                Spacer()
                if let toast = model.toast {
                    Text(toast)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.black.opacity(0.6)))
                        .padding(.bottom, 14)
                        .transition(.opacity)
                }
            }

            if case .interrupted(let reason) = model.status {
                Text(reason)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: Theme.radiusSmall).fill(.black.opacity(0.7)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(model.look == .looking ? Theme.ready : .clear, lineWidth: 3)
        )
        .animation(Theme.quick, value: model.look)
        .animation(Theme.quick, value: model.toast)
    }
}

private struct CameraMessage: View {
    let symbol: String
    let title: LocalizedStringKey
    var message: LocalizedStringKey? = nil
    var verbatim: String? = nil
    let button: LocalizedStringKey
    let action: @MainActor () -> Void

    init(symbol: String, title: LocalizedStringKey, message: LocalizedStringKey, button: LocalizedStringKey, action: @escaping @MainActor () -> Void) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.button = button
        self.action = action
    }

    init(symbol: String, title: LocalizedStringKey, verbatim: String, button: LocalizedStringKey, action: @escaping @MainActor () -> Void) {
        self.symbol = symbol
        self.title = title
        self.verbatim = verbatim
        self.button = button
        self.action = action
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34))
                .foregroundStyle(Theme.inkMuted)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            if let message {
                Text(message).font(.subheadline).foregroundStyle(Theme.inkMuted).multilineTextAlignment(.center)
            } else if let verbatim {
                Text(verbatim).font(.subheadline).foregroundStyle(Theme.inkMuted).multilineTextAlignment(.center)
            }
            Button(button) { action() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.treat)
                .foregroundStyle(.black)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

/// "Looking for a pet" → "Dog spotted" → "Looking!". Green only when the shot is on.
struct LookBadge: View {
    let model: PetCameraModel

    var body: some View {
        if model.isRunning {
            HStack(spacing: 6) {
                Image(systemName: model.look == .looking ? "eye.fill" : "pawprint.fill")
                Text(title)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(model.look == .looking ? Color.black : Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(model.look == .looking ? Theme.ready : Color.black.opacity(0.55)))
            .accessibilityElement(children: .combine)
        }
    }

    private var title: LocalizedStringKey {
        switch model.look {
        case .looking: return "Looking!"
        case .seen:
            switch model.species {
            case .cat: return "Cat spotted"
            case .dog: return "Dog spotted"
            case nil: return "Pet spotted"
            }
        case .none: return "Looking for a pet"
        }
    }
}

// MARK: - Controls

struct LurePill: View {
    let model: PetCameraModel

    var body: some View {
        Button {
            model.toggleLure()
        } label: {
            Label(model.lureIsLive ? "Lure ON" : "Lure", systemImage: "rectangle.on.rectangle.angled")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(model.lureIsLive ? Color.black : Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Capsule().fill(model.lureIsLive ? Theme.treat : Theme.chromeRaised))
        }
        .buttonStyle(.plain)
        .disabled(!model.lureAvailable)
        .opacity(model.lureAvailable ? 1 : 0.4)
        .accessibilityHint(Text("Shows a moving lure on the outer screen, facing your pet."))
    }
}

struct LureStrip: View {
    let model: PetCameraModel
    var vertical = false

    var body: some View {
        let chips = ForEach(Lure.allCases) { lure in
            LockableChip(
                symbol: lure.symbol,
                title: lure.title,
                selected: model.lure == lure,
                locked: !model.pro.isUnlocked(lure)
            ) {
                model.selectLure(lure)
            }
        }
        if vertical {
            VStack(spacing: 6) { chips }
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 8) { chips }
                    .padding(.horizontal, 12)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// Tap to play. Playing a sound also arms Catch for 3 seconds, so the look it causes is caught.
struct SoundPad: View {
    let model: PetCameraModel
    let columns: Int

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            ForEach(LureSound.allCases) { sound in
                Button {
                    model.call(sound)
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: sound.symbol)
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 28, height: 24)
                            if !model.pro.isUnlocked(sound) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.treat)
                                    .offset(x: 6, y: -4)
                            }
                        }
                        Text(sound.title)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(model.settings.sound == sound ? Theme.treat : Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.chromeRaised))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(sound.title))
                .accessibilityHint(Text("Plays the sound to get your pet’s attention."))
            }
        }
    }
}

struct LockableChip: View {
    let symbol: String
    let title: LocalizedStringKey
    let selected: Bool
    let locked: Bool
    let action: @MainActor () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: locked ? "lock.fill" : symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? Color.black : (locked ? Theme.inkMuted : Theme.ink))
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(Capsule().fill(selected ? Theme.treat : Theme.chromeRaised))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

struct CatchToggle: View {
    let model: PetCameraModel

    var body: some View {
        Button {
            model.settings.catchOn.toggle()
        } label: {
            Label(model.settings.catchOn ? "Catch ON" : "Catch", systemImage: "bolt.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(model.settings.catchOn ? Color.black : Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Capsule().fill(model.settings.catchOn ? Theme.ready : Theme.chromeRaised))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Takes the photo by itself the moment your pet looks at the camera."))
    }
}

struct ZoomChips: View {
    let model: PetCameraModel
    var vertical = false

    private var stops: [CGFloat] {
        var values: [CGFloat] = []
        if model.lens != .front, model.capabilities.hasUltraWide { values.append(model.capabilities.ultraWideZoom) }
        values.append(1)
        if model.capabilities.maxZoom >= 2 { values.append(2) }
        return values
    }

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 8))
        layout {
            ForEach(stops, id: \.self) { stop in
                let selected = abs(model.zoom - stop) < 0.05
                Button {
                    model.setZoom(stop)
                } label: {
                    Text(label(for: stop))
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(selected ? Theme.treat : Theme.ink)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.chromeRaised))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(label(for: stop)) zoom"))
            }
        }
    }

    private func label(for stop: CGFloat) -> String {
        stop < 1 ? String(format: "%.1f×", stop) : String(format: "%.0f×", stop)
    }
}

struct PetShutterButton: View {
    let model: PetCameraModel

    var body: some View {
        Button {
            model.shutterTapped()
        } label: {
            ZStack {
                Circle()
                    .stroke(Theme.ink, lineWidth: 4)
                    .frame(width: Theme.shutterSize, height: Theme.shutterSize)
                Circle()
                    .fill(model.look == .looking ? Theme.ready : Theme.ink)
                    .frame(width: Theme.shutterSize * 0.78, height: Theme.shutterSize * 0.78)
                if model.isCapturing {
                    ProgressView().tint(.black)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!model.isRunning || model.isCapturing)
        .accessibilityLabel(Text("Take photo"))
    }
}

struct FlipButton: View {
    let model: PetCameraModel

    var body: some View {
        Button {
            model.flipCamera()
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: Theme.minHit, height: Theme.minHit)
                .background(Circle().fill(Theme.chromeRaised))
        }
        .buttonStyle(.plain)
        .disabled(!model.capabilities.hasFront)
        .accessibilityLabel(Text("Switch camera"))
    }
}

struct LastShotThumb: View {
    let model: PetCameraModel
    let action: @MainActor () -> Void
    @State private var image: UIImage?

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.chromeRaised)
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .frame(width: Theme.minHit, height: Theme.minHit)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Open Roll"))
        .task(id: model.lastShot?.id ?? model.media.items.first?.id) {
            guard let item = model.lastShot ?? model.media.items.first else {
                image = nil
                return
            }
            image = await model.media.thumbnail(for: item)
        }
    }
}
