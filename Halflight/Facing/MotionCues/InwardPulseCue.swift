import SwiftUI

/// Concentric rounded rectangles pulse toward the centre. 12s loop, one ring every 3s.
enum InwardPulseCue {
    static func draw(in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.5)
        let maxW = size.width * 0.92
        let maxH = size.height * 0.92
        let rings = 5

        for i in 0..<rings {
            let p = CueMath.frac(t / 3 + Double(i) / Double(rings))
            let scale = 1 - CueMath.easeIn(p) * 0.92
            let alpha = CueMath.bump(p)
            let w = maxW * scale
            let h = maxH * scale
            let rect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
            let corner = min(w, h) * 0.22
            context.stroke(
                Path(roundedRect: rect, cornerRadius: corner),
                with: .color((i % 2 == 0 ? CuePalette.amber : CuePalette.cream).opacity(alpha)),
                lineWidth: 14 * scale + 4
            )
        }

        let pulse = 1 + 0.25 * sin(2 * .pi * t / 3)
        let r = min(size.width, size.height) * 0.05 * pulse
        let core = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: core), with: .color(CuePalette.cream))
    }
}
