import SwiftUI

/// Two dots get covered by two rounded shapes, then uncovered and look up at the camera. 8s loop.
enum HideSeekCue {
    static func draw(in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let cx = size.width / 2
        let cy = size.height * 0.5
        let eyeR = min(size.width, size.height) * 0.13
        let gap = eyeR * 1.5

        // Coverage: 0 = open, 1 = covered.
        let cover: Double
        switch t {
        case ..<1.0: cover = CueMath.easeInOut(t / 1.0)
        case ..<3.5: cover = 1
        case ..<4.5: cover = 1 - CueMath.easeInOut((t - 3.5) / 1.0)
        case ..<7.4: cover = 0
        default: cover = CueMath.easeInOut((t - 7.4) / 0.6)
        }

        // Pupils drift up to the camera while uncovered.
        let lookUp = cover < 0.5 ? CueMath.easeOut((t - 4.5) / 1.2) : 0
        let pupilOffset = CGPoint(x: 0, y: -eyeR * 0.35 * lookUp)

        for side in [-1.0, 1.0] {
            let eyeCenter = CGPoint(x: cx + side * gap, y: cy)
            let eyeRect = CGRect(x: eyeCenter.x - eyeR, y: eyeCenter.y - eyeR, width: eyeR * 2, height: eyeR * 2)
            context.fill(Path(ellipseIn: eyeRect), with: .color(CuePalette.cream))
            let pr = eyeR * 0.42
            let pupil = CGRect(x: eyeCenter.x - pr + pupilOffset.x, y: eyeCenter.y - pr + pupilOffset.y, width: pr * 2, height: pr * 2)
            context.fill(Path(ellipseIn: pupil), with: .color(CuePalette.dark))
        }

        // Hands: rounded rects rising from below to cover each eye.
        let handW = eyeR * 2.4
        let handH = eyeR * 2.6
        let restY = cy + eyeR * 2.8
        for side in [-1.0, 1.0] {
            let x = cx + side * gap - handW / 2
            let y = restY - (restY - (cy - handH / 2)) * cover
            let rect = CGRect(x: x, y: y, width: handW, height: handH)
            context.fill(Path(roundedRect: rect, cornerRadius: eyeR * 0.9), with: .color(CuePalette.amber))
        }

        // Camera marker
        let target = CuePalette.cameraTarget(in: size)
        let dot = CGRect(x: target.x - 6, y: target.y - 6, width: 12, height: 12)
        context.fill(Path(ellipseIn: dot), with: .color(CuePalette.cream.opacity(0.5 + 0.5 * lookUp)))
    }
}
