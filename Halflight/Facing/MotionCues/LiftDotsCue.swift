import SwiftUI

/// Five circles rise one after another and pop near the top. 10s loop.
enum LiftDotsCue {
    static func draw(in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let count = 5
        let radius = min(size.width, size.height) * 0.08
        let bottom = size.height + radius
        let top = size.height * 0.22
        let riseDuration = 3.0
        let popDuration = 0.5
        let stagger = 1.4

        for i in 0..<count {
            let startTime = Double(i) * stagger
            let local = t - startTime
            guard local >= 0, local <= riseDuration + popDuration else { continue }
            let x = size.width * (0.16 + 0.17 * Double(i))

            if local <= riseDuration {
                let p = CueMath.easeOut(local / riseDuration)
                let y = bottom - (bottom - top) * p
                let wobble = sin(local * 4 + Double(i)) * radius * 0.15
                let rect = CGRect(x: x - radius + wobble, y: y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(i % 2 == 0 ? CuePalette.amber : CuePalette.cream))
            } else {
                let p = (local - riseDuration) / popDuration
                let scale = 1 + 0.8 * p
                let alpha = 1 - p
                let r = radius * scale
                let rect = CGRect(x: x - r, y: top - r, width: r * 2, height: r * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(CuePalette.cream.opacity(alpha)), lineWidth: radius * 0.35 * (1 - p) + 2)
            }
        }
    }
}
