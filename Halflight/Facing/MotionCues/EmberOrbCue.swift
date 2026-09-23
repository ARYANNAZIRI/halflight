import SwiftUI

/// A warm circle breathes, then hops toward the camera cutout every three seconds. 12s loop.
enum EmberOrbCue {
    static func draw(in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.58)
        let target = CuePalette.cameraTarget(in: size)
        let base = min(size.width, size.height) * 0.22

        let breath = 1 + 0.10 * sin(2 * .pi * t / 4)
        let hopPhase = CueMath.frac(t / 3)
        let hop = CueMath.bump(hopPhase * 1.6)
        let y = center.y - (center.y - target.y - base * 0.9) * CueMath.easeInOut(hop)
        let squash = 1 + 0.10 * hop

        let radius = base * breath
        let position = CGPoint(x: center.x, y: y)

        // Glow
        let glowRect = CGRect(x: position.x - radius * 1.5, y: position.y - radius * 1.5, width: radius * 3, height: radius * 3)
        context.fill(Path(ellipseIn: glowRect), with: .color(CuePalette.glow))

        // Orb, slightly stretched while it hops
        let orbRect = CGRect(
            x: position.x - radius / squash,
            y: position.y - radius * squash,
            width: radius * 2 / squash,
            height: radius * 2 * squash
        )
        context.fill(Path(ellipseIn: orbRect), with: .color(CuePalette.amber))

        // Highlight
        let hl = radius * 0.28
        let hlRect = CGRect(x: position.x - radius * 0.45, y: position.y - radius * 0.55, width: hl, height: hl)
        context.fill(Path(ellipseIn: hlRect), with: .color(CuePalette.cream.opacity(0.9)))

        // Small marker at the camera so the eye has somewhere to land
        let dot = CGRect(x: target.x - 6, y: target.y - 6, width: 12, height: 12)
        context.fill(Path(ellipseIn: dot), with: .color(CuePalette.cream.opacity(0.6 + 0.4 * hop)))
    }
}
