import AudioToolbox
import SwiftUI

/// Seamless looping renderer for a `MotionCue`. Time-driven Canvas, no timers, no assets.
struct MotionCuePlayer: View {
    let cue: MotionCue
    var soundOn = false
    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(start)
            let t = max(0, elapsed.truncatingRemainder(dividingBy: cue.loopDuration))
            Canvas(rendersAsynchronously: true) { graphics, size in
                MotionCueRenderer.draw(cue, in: &graphics, size: size, t: t)
            }
        }
        .background(Theme.navy)
        .onChange(of: cue) { _, _ in start = .now }
        .task(id: "\(cue.rawValue)-\(soundOn)") {
            await CueSound.run(cue: cue, enabled: soundOn)
        }
        .accessibilityLabel(Text(cue.title))
    }
}

enum MotionCueRenderer {
    static func draw(_ cue: MotionCue, in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        switch cue {
        case .emberOrb: EmberOrbCue.draw(in: &context, size: size, t: t)
        case .hideSeek: HideSeekCue.draw(in: &context, size: size, t: t)
        case .liftDots: LiftDotsCue.draw(in: &context, size: size, t: t)
        case .slowRing: SlowRingCue.draw(in: &context, size: size, t: t)
        case .softBlob: SoftBlobCue.draw(in: &context, size: size, t: t)
        case .inwardPulse: InwardPulseCue.draw(in: &context, size: size, t: t)
        }
    }
}

/// Palette and easing shared by the cues. High contrast only.
enum CuePalette {
    static let amber = Theme.amber
    static let cream = Color(red: 0.98, green: 0.93, blue: 0.82)
    static let dark = Color(red: 0.05, green: 0.06, blue: 0.10)
    static let glow = Theme.amber.opacity(0.25)

    /// Where the outer camera lives: top centre of the outer display.
    static func cameraTarget(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: 36)
    }
}

enum CueMath {
    static func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }
    static func frac(_ x: Double) -> Double { x - floor(x) }
    static func easeInOut(_ x: Double) -> Double {
        let x = clamp01(x)
        return x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
    }
    static func easeOut(_ x: Double) -> Double { 1 - pow(1 - clamp01(x), 3) }
    static func easeIn(_ x: Double) -> Double { pow(clamp01(x), 3) }
    /// Smooth bump 0→1→0 over 0...1.
    static func bump(_ x: Double) -> Double { sin(.pi * clamp01(x)) }
}

/// Optional tick on each cue beat. Off by default; uses a system sound so there are no assets.
enum CueSound {
    static func run(cue: MotionCue, enabled: Bool) async {
        guard enabled else { return }
        let start = Date.now
        let beats = cue.beats.sorted()
        guard !beats.isEmpty else { return }
        while !Task.isCancelled {
            let elapsed = Date.now.timeIntervalSince(start).truncatingRemainder(dividingBy: cue.loopDuration)
            let next = beats.first(where: { $0 > elapsed + 0.01 }) ?? (beats[0] + cue.loopDuration)
            let wait = max(0.05, next - elapsed)
            try? await Task.sleep(for: .seconds(wait))
            if Task.isCancelled { return }
            AudioServicesPlaySystemSound(1104)
        }
    }
}
