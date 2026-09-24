import SwiftUI

/// Seamless looping renderer for a `Lure`. Time-driven Canvas: no timers, no assets.
struct LurePlayer: View {
    let lure: Lure
    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(start)
            let t = max(0, elapsed.truncatingRemainder(dividingBy: lure.loopDuration))
            Canvas(rendersAsynchronously: true) { graphics, size in
                LureRenderer.draw(lure, in: &graphics, size: size, t: t)
            }
        }
        .background(LurePalette.backdrop)
        .onChange(of: lure) { _, _ in start = .now }
        .accessibilityLabel(Text(lure.title))
    }
}

enum LureRenderer {
    static func draw(_ lure: Lure, in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        switch lure {
        case .zipDot: ZipDotLure.draw(in: &context, size: size, t: t)
        case .bouncyBall: BouncyBallLure.draw(in: &context, size: size, t: t)
        case .feather: FeatherLure.draw(in: &context, size: size, t: t)
        case .mouse: MouseLure.draw(in: &context, size: size, t: t)
        case .bubbles: BubblesLure.draw(in: &context, size: size, t: t)
        case .peekPaw: PeekPawLure.draw(in: &context, size: size, t: t)
        }
    }
}

/// Blue and yellow: the two hues cats and dogs tell apart best. Red reads as dull grey to them.
enum LurePalette {
    static let backdrop = Color(red: 0.03, green: 0.04, blue: 0.08)
    static let yellow = Color(red: 1.0, green: 0.84, blue: 0.20)
    static let blue = Color(red: 0.24, green: 0.52, blue: 1.0)
    static let white = Color(red: 0.97, green: 0.97, blue: 1.0)
    static let dark = Color(red: 0.05, green: 0.06, blue: 0.10)

    /// Where the outer camera lives: top centre of the outer display.
    static func lens(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: 36)
    }
}

enum LureMath {
    static func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }
    static func easeInOut(_ x: Double) -> Double {
        let x = clamp01(x)
        return x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
    }
    static func easeOut(_ x: Double) -> Double { 1 - pow(1 - clamp01(x), 3) }
    static func bump(_ x: Double) -> Double { sin(.pi * clamp01(x)) }

    static func lerp(_ a: CGPoint, _ b: CGPoint, _ x: Double) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * x, y: a.y + (b.y - a.y) * x)
    }

    static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
