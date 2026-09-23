import SwiftUI

/// Outer-display content. This is the subject's screen: never a setting, never the roll.
/// Big type, thick strokes, reads in sunlight.
struct FacingView: View {
    let model: CaptureModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch model.facingMode {
            case .mirror: FacingMirrorView(model: model)
            case .motionCue: FacingMotionCueView(model: model)
            case .prompt: FacingPromptView(model: model)
            case .count: FacingCountView(model: model)
            case .off: Color.black
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}

/// Short caption for the subject. Heavy weight and a double shadow so it survives direct sun.
struct FacingCaption: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.system(size: 36, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.95), radius: 2)
            .shadow(color: .black.opacity(0.8), radius: 10)
            .padding(.horizontal, 24)
            .multilineTextAlignment(.center)
    }
}

struct BigNumber: View {
    let value: Int
    var color: Color = .white

    var body: some View {
        Text("\(value)")
            .font(.system(size: 240, weight: .bold, design: .rounded).monospacedDigit())
            .minimumScaleFactor(0.3)
            .foregroundStyle(color)
            .contentTransition(.numericText(countsDown: true))
            .shadow(color: .black.opacity(0.6), radius: 12)
            .accessibilityLabel(Text("Countdown"))
            .accessibilityValue(Text("\(value)"))
    }
}

struct FacingMirrorView: View {
    let model: CaptureModel

    var body: some View {
        ZStack {
            if let source = model.previewSource {
                CameraPreviewView(source: source, mirrored: true)
                    .ignoresSafeArea()
            } else {
                Color.black
            }

            if model.showPoseSilhouette {
                Image(systemName: "figure.stand")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.22))
                    .padding(48)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            VStack {
                Spacer()
                FacingCaption(text: caption)
                    .padding(.bottom, 44)
            }

            if model.mirrorCountdown, let countdown = model.countdown, countdown > 0 {
                BigNumber(value: countdown)
            }
        }
        .animation(Theme.quick, value: model.countdown)
    }

    private var caption: LocalizedStringKey {
        if model.autoCaptureWarning != nil || model.handsFree || model.countdown != nil {
            return "Hold still"
        }
        return "Look here"
    }
}

struct FacingMotionCueView: View {
    let model: CaptureModel

    var body: some View {
        MotionCuePlayer(cue: model.cue, soundOn: model.settings.cueSoundOn)
            .ignoresSafeArea()
            // Fixed size on purpose: Motion Cue is not a text surface.
            .dynamicTypeSize(.large)
    }
}

struct FacingPromptView: View {
    let model: CaptureModel

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                if let script = model.promptScript, !script.body.isEmpty {
                    TimelineView(.animation(paused: !model.promptPlaying)) { context in
                        let elapsed = model.promptElapsed(at: context.date)
                        let offset = CGFloat(elapsed * model.promptSpeed)
                        Text(script.body)
                            .font(.system(size: model.promptFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(model.promptFontSize * 0.25)
                            .frame(width: max(0, proxy.size.width - 48))
                            .fixedSize(horizontal: false, vertical: true)
                            .offset(y: proxy.size.height * 0.42 - offset)
                            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                            .clipped()
                    }
                } else {
                    VStack {
                        Spacer()
                        FacingCaption(text: "Look here")
                        Spacer()
                    }
                    .frame(width: proxy.size.width)
                }

                // Reading line: where the eye should rest, close to the outer camera.
                Rectangle()
                    .fill(Theme.amber.opacity(0.8))
                    .frame(height: 3)
                    .padding(.horizontal, 24)
                    .offset(y: proxy.size.height * 0.30)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .scaleEffect(x: model.promptMirrored ? -1 : 1, y: 1)
        .background(Color.black)
    }
}

struct FacingCountView: View {
    let model: CaptureModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let frame = model.freezeFrame {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .accessibilityLabel(Text("Your photo"))
            } else if let countdown = model.countdown, countdown > 0 {
                (countdown == 1 ? Theme.amber : Color.black).ignoresSafeArea()
                BigNumber(value: countdown, color: countdown == 1 ? Theme.chrome : .white)
            } else {
                VStack(spacing: 28) {
                    Circle()
                        .stroke(model.hint == .ready ? Theme.amber : Color.white.opacity(0.35), lineWidth: 10)
                        .frame(width: 180, height: 180)
                    FacingCaption(text: model.hint == .ready ? "Ready" : "Look here")
                }
            }
        }
        .animation(Theme.quick, value: model.countdown)
        .animation(Theme.quick, value: model.hint)
        .animation(Theme.quick, value: model.freezeFrame == nil)
    }
}

/// Full-screen Motion Cue on the same display for phones without an outer screen.
struct MotionCueOverlay: View {
    let model: CaptureModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            MotionCuePlayer(cue: model.cue, soundOn: model.settings.cueSoundOn)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { model.cycleCue() }
                .accessibilityHint(Text("Double tap to change the cue."))

            VStack {
                HStack {
                    ChromeButton(symbol: "xmark", label: "Close") { dismiss() }
                    Spacer()
                    Text(model.cue.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                    Spacer()
                    ChromeChip(text: "Mix", symbol: "shuffle", active: model.mixCues) {
                        model.setMixCues(!model.mixCues)
                    }
                }
                Spacer()
                HStack {
                    HintBadge(model: model)
                    Spacer()
                }
                ShutterButton(model: model)
                    .padding(.bottom, 12)
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
        .captureAlert(model)
        .task { await model.start() }
    }
}
