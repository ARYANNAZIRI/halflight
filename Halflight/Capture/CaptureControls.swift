import SwiftUI

// MARK: - Shutter

/// Large white ring. No bounce: a 4% press scale and nothing else.
struct ShutterButton: View {
    let model: CaptureModel
    var size: CGFloat = Theme.shutterSize

    var body: some View {
        Button {
            model.shutterTapped()
        } label: {
            ZStack {
                Circle()
                    .stroke(Theme.ink, lineWidth: 4)
                    .frame(width: size, height: size)
                if model.mode == .video {
                    RoundedRectangle(cornerRadius: model.isRecording ? 6 : size / 2, style: .continuous)
                        .fill(Theme.danger)
                        .frame(width: model.isRecording ? size * 0.40 : size * 0.78,
                               height: model.isRecording ? size * 0.40 : size * 0.78)
                        .animation(Theme.snap, value: model.isRecording)
                } else {
                    Circle()
                        .fill(model.countdown != nil ? Theme.amber : Theme.ink)
                        .frame(width: size * 0.78, height: size * 0.78)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(ShutterPressStyle())
        .disabled(!model.isRunning && model.countdown == nil)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(model.mode == .photo ? Text("Takes a photo.") : Text("Starts or stops recording."))
    }

    private var accessibilityLabel: Text {
        if model.countdown != nil { return Text("Cancel timer") }
        switch model.mode {
        case .photo: return Text("Take photo")
        case .video: return model.isRecording ? Text("Stop recording") : Text("Start recording")
        }
    }
}

struct ShutterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Small chrome buttons

struct ChromeButton: View {
    let symbol: String
    var label: LocalizedStringKey
    var active = false
    var size: CGFloat = Theme.minHit
    let action: @MainActor () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(active ? Theme.amber : Theme.ink)
                .frame(width: size, height: size)
                .background(Circle().fill(Theme.chromeRaised.opacity(0.85)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}

struct ChromeChip: View {
    let text: LocalizedStringKey
    var symbol: String? = nil
    var active = false
    let action: @MainActor () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol).font(.system(size: 12, weight: .semibold)) }
                Text(text).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(active ? Theme.chrome : Theme.ink)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(active ? Theme.amber : Theme.chromeRaised.opacity(0.85)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}

// MARK: - Mode, lens

struct ModePicker: View {
    let model: CaptureModel
    var vertical = false

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 18))
        layout {
            ForEach(CameraSession.CaptureMode.allCases) { mode in
                Button {
                    model.setMode(mode)
                } label: {
                    Text(mode == .photo ? "Photo" : "Video")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(model.mode == mode ? Theme.amber : Theme.inkMuted)
                        .frame(minWidth: 56, minHeight: 36)
                }
                .buttonStyle(.plain)
                .disabled(model.isRecording)
                .accessibilityAddTraits(model.mode == mode ? [.isSelected] : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Capture mode"))
    }
}

struct LensChips: View {
    let model: CaptureModel
    var vertical = false

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 8))
        layout {
            if model.lens != .front {
                if model.capabilities.hasUltraWide {
                    ChromeChip(text: "0.5", active: model.lens == .ultraWide) { model.setLens(.ultraWide) }
                        .accessibilityLabel(Text("Ultra wide"))
                }
                ChromeChip(text: "1x", active: model.lens == .main && model.zoom < 1.5) {
                    model.setLens(.main)
                    model.setZoom(1)
                }
                .accessibilityLabel(Text("Main camera"))
                ChromeChip(text: "2x", active: model.lens == .main && model.zoom >= 1.5) {
                    if model.lens != .main { model.setLens(.main) }
                    model.setZoom(2)
                }
                .accessibilityLabel(Text("2x zoom"))
            } else {
                ChromeChip(text: "Front", symbol: "person.crop.circle", active: true) {}
                    .accessibilityHidden(true)
            }
        }
    }
}

struct FlipButton: View {
    let model: CaptureModel

    var body: some View {
        ChromeButton(symbol: "arrow.triangle.2.circlepath.camera", label: "Switch camera", size: 52) {
            model.flipCamera()
        }
        .disabled(!model.capabilities.hasFront || model.isRecording)
        .opacity(model.capabilities.hasFront ? 1 : 0.4)
    }
}

// MARK: - State chips

struct TimerChip: View {
    let model: CaptureModel

    var body: some View {
        ChromeChip(
            text: model.timer == .off ? "Timer" : model.timer.title,
            symbol: "timer",
            active: model.timer != .off || model.handsFree,
            action: { model.cycleTimer() }
        )
        .accessibilityLabel(Text("Timer"))
        .accessibilityValue(Text(model.timer.title))
    }
}

struct FlashChip: View {
    let model: CaptureModel

    var body: some View {
        ChromeButton(symbol: symbol, label: "Flash", active: model.flash != .off) { model.cycleFlash() }
            .disabled(!model.capabilities.hasFlash || model.mode == .video)
            .opacity(model.capabilities.hasFlash ? 1 : 0.4)
            .accessibilityValue(Text(model.flash.rawValue))
    }

    private var symbol: String {
        switch model.flash {
        case .off: "bolt.slash"
        case .auto: "bolt.badge.automatic"
        case .on: "bolt.fill"
        }
    }
}

struct FacingPill: View {
    @Bindable var model: CaptureModel

    var body: some View {
        Button {
            withAnimation(Theme.snap) { model.facingEnabled.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: model.facingMode.symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(model.facingEnabled ? "Facing ON" : "Facing")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(model.facingEnabled ? Theme.chrome : Theme.ink)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Capsule().fill(model.facingEnabled ? Theme.amber : Theme.chromeRaised.opacity(0.85)))
            .overlay(Capsule().stroke(Theme.amber.opacity(model.facingAvailable ? 0.9 : 0), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!model.facingAvailable || model.facingMode == .off)
        .opacity(model.facingAvailable ? 1 : 0.45)
        .accessibilityLabel(Text("Facing"))
        .accessibilityValue(model.facingEnabled ? Text("On") : Text("Off"))
        .accessibilityHint(Text("Shows a preview, cue, or script on the outer display."))
    }
}

/// Pictogram strip to pick the Facing mode from the inner display.
struct FacingModeStrip: View {
    let model: CaptureModel
    var vertical = false

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))
        layout {
            ForEach(FacingMode.allCases) { mode in
                Button {
                    model.setFacingMode(mode)
                } label: {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(model.facingMode == mode ? Theme.amber : Theme.inkMuted)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(model.facingMode == mode ? Theme.chromeRaised : .clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(mode.title))
                .accessibilityAddTraits(model.facingMode == mode ? [.isSelected] : [])
            }
        }
    }
}

struct LastShotThumb: View {
    let model: CaptureModel
    let action: @MainActor () -> Void
    @State private var image: UIImage?

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.chromeRaised)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                if model.lastShot?.isVideo == true {
                    Image(systemName: "play.fill").font(.system(size: 12)).foregroundStyle(Theme.ink)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Last shot. Opens Roll."))
        .task(id: model.lastShot?.id) {
            guard let item = model.lastShot else { image = nil; return }
            image = await model.media.thumbnail(for: item)
        }
    }
}

// MARK: - Overlays

struct GridOverlay: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            for i in 1...2 {
                let x = size.width * CGFloat(i) / 3
                let y = size.height * CGFloat(i) / 3
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct LevelIndicator: View {
    let level: MotionLevel

    var body: some View {
        ZStack {
            Rectangle().fill(Theme.inkFaint).frame(width: 120, height: 1)
            Rectangle()
                .fill(level.isLevel ? Theme.amber : Theme.ink)
                .frame(width: 80, height: 2)
                .rotationEffect(.degrees(-level.tilt))
                .animation(.linear(duration: 0.05), value: level.tilt)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct FocusReticle: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(Theme.amber, lineWidth: 1.5)
            .frame(width: 72, height: 72)
            .transition(.opacity)
            .allowsHitTesting(false)
    }
}

struct RecordingBadge: View {
    let start: Date

    var body: some View {
        TimelineView(.periodic(from: start, by: 1)) { context in
            let seconds = Int(context.date.timeIntervalSince(start))
            HStack(spacing: 6) {
                Circle().fill(Theme.danger).frame(width: 8, height: 8)
                Text(Self.format(seconds))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Capsule().fill(Color.black.opacity(0.55)))
            .accessibilityLabel(Text("Recording"))
            .accessibilityValue(Text(Self.format(seconds)))
        }
    }

    static func format(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

struct CountdownBadge: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .font(.system(size: 96, weight: .thin, design: .rounded).monospacedDigit())
            .foregroundStyle(Theme.ink)
            .contentTransition(.numericText(countsDown: true))
            .shadow(radius: 12)
            .accessibilityLabel(Text("Timer"))
            .accessibilityValue(Text("\(value)"))
    }
}

struct HintBadge: View {
    let model: CaptureModel

    var body: some View {
        if let warning = model.autoCaptureWarning {
            Text("Auto in \(warning)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.chrome)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Capsule().fill(Theme.amber))
        } else if model.hint == .ready {
            Text("Ready")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.amber)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .overlay(Capsule().stroke(Theme.amber.opacity(0.7), lineWidth: 1))
                .transition(.opacity)
        }
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Capsule().fill(Theme.chromeRaised))
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

struct InterruptedBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pause.circle")
            Text(message)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Capsule().fill(Color.black.opacity(0.6)))
    }
}

// MARK: - Viewfinder

struct ViewfinderView: View {
    let model: CaptureModel
    let level: MotionLevel
    @State private var pinchStart: CGFloat?

    var body: some View {
        ZStack {
            switch model.status {
            case .unauthorized:
                CameraDeniedView()
            case .failed(let message):
                CameraFailedView(message: message) { model.retry() }
            default:
                if let source = model.previewSource {
                    CameraPreviewView(source: source) { viewPoint, devicePoint in
                        model.focus(viewPoint: viewPoint, devicePoint: devicePoint)
                    }
                } else {
                    Color.black
                    ProgressView().tint(Theme.inkMuted)
                }
            }

            if model.gridOn { GridOverlay() }
            if model.levelOn { LevelIndicator(level: level) }
            if let point = model.focusPoint { FocusReticle().position(point) }

            VStack {
                HStack(alignment: .top) {
                    if model.isRecording, let start = model.recordingStart { RecordingBadge(start: start) }
                    Spacer()
                    HintBadge(model: model)
                }
                .padding(12)
                Spacer()
                if case .interrupted(let reason) = model.status {
                    InterruptedBanner(message: reason).padding(.bottom, 12)
                }
            }

            if let countdown = model.countdown, countdown > 0 {
                CountdownBadge(value: countdown)
            }

            if let toast = model.toast {
                VStack {
                    Spacer()
                    ToastView(text: toast).padding(.bottom, 16)
                }
            }
        }
        .animation(Theme.quick, value: model.toast)
        .animation(Theme.quick, value: model.hint)
        .animation(Theme.quick, value: model.focusPoint)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    if pinchStart == nil { pinchStart = model.zoom }
                    model.setZoom((pinchStart ?? 1) * value.magnification)
                }
                .onEnded { _ in pinchStart = nil }
        )
    }
}

struct CameraDeniedView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.inkMuted)
            Text("Camera access is off")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("Halflight is a camera. Allow it in Settings to see the viewfinder.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
            Button("Open Settings") { Permissions.openSystemSettings() }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.chromeRaised.opacity(0.4))
    }
}

struct CameraFailedView: View {
    let message: String
    let retry: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.inkMuted)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
            Button("Try again") { retry() }
                .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.chromeRaised.opacity(0.4))
    }
}

// MARK: - More sheet

struct MoreControlsSheet: View {
    @Bindable var model: CaptureModel
    let level: MotionLevel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Flash", selection: $model.flash) {
                        ForEach(CameraSession.FlashMode.allCases) { mode in
                            Text(mode.rawValue.capitalized).tag(mode)
                        }
                    }
                    .disabled(!model.capabilities.hasFlash)
                    Picker("Timer", selection: $model.timer) {
                        ForEach(CaptureModel.TimerOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Toggle("Burst (5 shots)", isOn: $model.burstOn)
                    Toggle("Torch", isOn: Binding(get: { model.torchOn }, set: { model.setTorch($0) }))
                        .disabled(!model.capabilities.hasTorch)
                }
                Section("Exposure") {
                    Slider(
                        value: Binding(get: { model.exposureBias }, set: { model.setExposureBias($0) }),
                        in: Double(model.capabilities.minExposureBias)...Double(model.capabilities.maxExposureBias),
                        step: 0.1
                    )
                    .accessibilityLabel(Text("Exposure"))
                    Button("Reset exposure") { model.setExposureBias(0) }
                        .disabled(model.exposureBias == 0)
                }
                Section("Overlays") {
                    Toggle("Grid", isOn: $model.gridOn)
                    Toggle("Level", isOn: Binding(get: { model.levelOn }, set: { on in
                        model.levelOn = on
                        if on { level.start() } else { level.stop() }
                    }))
                }
                Section {
                    Toggle("Auto-Capture when Ready", isOn: $model.autoCapture)
                } footer: {
                    Text("Takes the shot on its own when faces are steady. A 2-second warning shows first.")
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.chrome)
    }
}
