import SwiftUI

/// A rounded shape with two eyes waves one arm, then rests. Blinks twice. 8s loop.
enum SoftBlobCue {
    static func draw(in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let cx = size.width / 2
        let cy = size.height * 0.56
        let base = min(size.width, size.height) * 0.30
        let wobble = sin(2 * .pi * t / 2)
        let w = base * 2 * (1 + 0.04 * wobble)
        let h = base * 1.8 * (1 - 0.04 * wobble)

        // Arm behind the body
        let waving = t < 4.2
        let armAngle = waving ? (-0.45 + 0.5 * sin(2 * .pi * t / 1.2)) : -0.05
        let armLength = base * 0.9
        let shoulder = CGPoint(x: cx + w * 0.42, y: cy - h * 0.05)
        let hand = CGPoint(x: shoulder.x + cos(armAngle) * armLength, y: shoulder.y + sin(armAngle) * armLength)
        var arm = Path()
        arm.move(to: shoulder)
        arm.addLine(to: hand)
        context.stroke(arm, with: .color(CuePalette.amber), style: StrokeStyle(lineWidth: base * 0.32, lineCap: .round))

        // Body
        let body = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
        context.fill(Path(roundedRect: body, cornerRadius: base * 0.7), with: .color(CuePalette.cream))

        // Eyes with two blinks
        let blink = blinkAmount(t, at: 3.0) + blinkAmount(t, at: 6.6)
        let eyeR = base * 0.16
        let eyeH = eyeR * 2 * max(0.08, 1 - blink)
        for side in [-1.0, 1.0] {
            let ex = cx + side * base * 0.42
            let ey = cy - h * 0.12
            let rect = CGRect(x: ex - eyeR, y: ey - eyeH / 2, width: eyeR * 2, height: eyeH)
            context.fill(Path(ellipseIn: rect), with: .color(CuePalette.dark))
        }

        // Mouth
        var mouth = Path()
        mouth.addArc(center: CGPoint(x: cx, y: cy + h * 0.16), radius: base * 0.28, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
        context.stroke(mouth, with: .color(CuePalette.dark), style: StrokeStyle(lineWidth: base * 0.08, lineCap: .round))
    }

    private static func blinkAmount(_ t: TimeInterval, at time: TimeInterval) -> Double {
        let d = abs(t - time)
        return d < 0.12 ? 1 - d / 0.12 : 0
    }
}
