import SwiftUI

// Each lure: fast, high-contrast motion for the first part of the loop, then it settles
// right under the lens so the pet's eyes end up on the camera.

/// A bright dot that darts between points, pauses, and finishes under the lens. 6s loop.
enum ZipDotLure {
    static func draw(in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let lens = LurePalette.lens(in: size)
        let stops: [CGPoint] = [
            CGPoint(x: size.width * 0.2, y: size.height * 0.75),
            CGPoint(x: size.width * 0.8, y: size.height * 0.55),
            CGPoint(x: size.width * 0.3, y: size.height * 0.35),
            CGPoint(x: size.width * 0.75, y: size.height * 0.85),
            CGPoint(x: size.width * 0.5, y: size.height * 0.5),
            CGPoint(x: lens.x, y: lens.y + 70),
        ]
        // 5 hops of 0.8s (0.35s move, 0.45s pause), then rest under the lens.
        let hop = 0.8
        let index = min(Int(t / hop), stops.count - 1)
        let point: CGPoint
        if index >= stops.count - 1 {
            point = stops[stops.count - 1]
        } else {
            let local = (t - Double(index) * hop) / 0.35
            point = LureMath.lerp(stops[index], stops[index + 1], LureMath.easeInOut(local))
        }
        let resting = index >= stops.count - 1
        let pulse: Double = resting ? 1 + 0.25 * sin(2 * .pi * t * 2.5) : 1
        let radius = CGFloat(22 * pulse)

        context.fill(LureMath.circle(point, radius * 2.4), with: .color(LurePalette.yellow.opacity(0.18)))
        context.fill(LureMath.circle(point, radius), with: .color(LurePalette.yellow))
        context.fill(LureMath.circle(point, radius * 0.45), with: .color(LurePalette.white))
    }
}

/// A blue ball bouncing with squash and stretch, climbing toward the lens. 4s loop.
enum BouncyBallLure {
    static func draw(in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let lens = LurePalette.lens(in: size)
        let radius = min(size.width, size.height) * 0.12
        let bounces = 4.0
        let phase = (t / 4) * bounces
        let local = phase - floor(phase)
        let bounceIndex = floor(phase)

        // Each bounce lands a little higher, so the last apex sits just under the lens.
        let floorY = size.height - radius - 24
        let apexY = lens.y + radius + 40 + CGFloat(bounces - 1 - bounceIndex) * size.height * 0.1
        let height = floorY - apexY
        let y = floorY - height * CGFloat(4 * local * (1 - local))
        let swing = 0.5 + 0.5 * sin(2 * .pi * t / 4)
        let x = size.width * CGFloat(0.25 + 0.5 * swing)

        // Squash near the floor, stretch in flight.
        let nearFloor: Double = 1 - min(1, local * 12, (1 - local) * 12)
        let squash = CGFloat(1 + 0.35 * nearFloor)
        let w = radius * 2 * squash
        let h = radius * 2 / squash
        // Keep the squashed ball sitting on the floor instead of shrinking around its centre.
        let rect = CGRect(x: x - w / 2, y: y + radius - h, width: w, height: h)

        context.fill(Path(ellipseIn: CGRect(x: x - radius, y: floorY + radius - 6, width: radius * 2, height: 12)),
                     with: .color(.black.opacity(0.35)))
        context.fill(Path(ellipseIn: rect), with: .color(LurePalette.blue))
        // Yellow stripe so the spin reads even at a glance.
        var stripe = Path()
        stripe.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: min(w, h) * 0.32,
                      startAngle: .radians(t * 6), endAngle: .radians(t * 6 + .pi), clockwise: false)
        context.stroke(stripe, with: .color(LurePalette.yellow), style: StrokeStyle(lineWidth: radius * 0.22, lineCap: .round))
    }
}

/// A feather on a string, swinging and twitching, pulled up to the lens at the end. 6s loop.
enum FeatherLure {
    static func draw(in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let lens = LurePalette.lens(in: size)
        let anchor = CGPoint(x: lens.x, y: 0)
        // Swing for 4.5s, then reel in for the last 1.5s.
        let reel = LureMath.easeInOut((t - 4.5) / 1.5)
        let length = size.height * 0.62 * CGFloat(1 - reel) + CGFloat(90 * reel)
        let twitch = 0.12 * sin(2 * .pi * t * 3.1)
        let angle: Double = (0.7 * sin(2 * .pi * t / 1.6) + twitch) * (1 - reel)
        let tip = CGPoint(x: anchor.x + CGFloat(sin(angle)) * length, y: anchor.y + CGFloat(cos(angle)) * length)

        var string = Path()
        string.move(to: anchor)
        string.addLine(to: tip)
        context.stroke(string, with: .color(LurePalette.white.opacity(0.6)), lineWidth: 2)

        // Feather: a long leaf shape with a spine, rotated with the swing.
        var feather = context
        feather.translateBy(x: tip.x, y: tip.y)
        feather.rotate(by: .radians(-angle + 0.25 * sin(2 * .pi * t * 2)))
        let length2: CGFloat = min(size.width, size.height) * 0.34
        let width2: CGFloat = length2 * 0.32
        var shape = Path()
        shape.move(to: .zero)
        shape.addQuadCurve(to: CGPoint(x: 0, y: length2), control: CGPoint(x: width2, y: length2 * 0.45))
        shape.addQuadCurve(to: .zero, control: CGPoint(x: -width2, y: length2 * 0.45))
        feather.fill(shape, with: .color(LurePalette.yellow))
        var spine = Path()
        spine.move(to: .zero)
        spine.addLine(to: CGPoint(x: 0, y: length2))
        feather.stroke(spine, with: .color(LurePalette.blue), lineWidth: 3)
        for i in 1..<6 {
            let y = length2 * CGFloat(i) / 6
            var barb = Path()
            barb.move(to: CGPoint(x: 0, y: y))
            barb.addLine(to: CGPoint(x: width2 * 0.55, y: y + 10))
            barb.move(to: CGPoint(x: 0, y: y))
            barb.addLine(to: CGPoint(x: -width2 * 0.55, y: y + 10))
            feather.stroke(barb, with: .color(LurePalette.blue.opacity(0.7)), lineWidth: 1.5)
        }
    }
}

/// A little mouse that scurries along the edges, stops, then pops up by the lens. 8s loop.
enum MouseLure {
    static func draw(in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let lens = LurePalette.lens(in: size)
        let margin: CGFloat = 50
        let path: [CGPoint] = [
            CGPoint(x: -60, y: size.height - margin),
            CGPoint(x: size.width * 0.6, y: size.height - margin),
            CGPoint(x: size.width - margin, y: size.height * 0.6),
            CGPoint(x: size.width - margin, y: size.height * 0.35),
            CGPoint(x: size.width * 0.3, y: size.height * 0.4),
            CGPoint(x: lens.x, y: lens.y + 80),
        ]
        // Five legs of 1.2s each with a short stop, then 2s sitting by the lens.
        let leg = 1.2
        let index = min(Int(t / leg), path.count - 1)
        let point: CGPoint
        let heading: Double
        if index >= path.count - 1 {
            point = path[path.count - 1]
            heading = -.pi / 2
        } else {
            let local = min(1, (t - Double(index) * leg) / 0.9)
            let from = path[index]
            let to = path[index + 1]
            point = LureMath.lerp(from, to, LureMath.easeInOut(local))
            heading = Double(atan2(to.y - from.y, to.x - from.x))
        }
        let sitting = index >= path.count - 1
        let scale = min(size.width, size.height) / 300

        var mouse = context
        mouse.translateBy(x: point.x, y: point.y)
        mouse.rotate(by: .radians(heading))
        mouse.scaleBy(x: scale, y: scale)

        // Tail (wiggles), body, ears, eye, nose. Drawn facing +x.
        var tail = Path()
        tail.move(to: CGPoint(x: -34, y: 0))
        tail.addCurve(to: CGPoint(x: -90, y: 0),
                      control1: CGPoint(x: -55, y: 18 * sin(t * 12)),
                      control2: CGPoint(x: -72, y: -18 * sin(t * 12)))
        mouse.stroke(tail, with: .color(LurePalette.white.opacity(0.8)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        mouse.fill(Path(ellipseIn: CGRect(x: -40, y: -22, width: 80, height: 44)), with: .color(LurePalette.white))
        let earLift: CGFloat = sitting ? CGFloat(4 * sin(t * 8)) : 0
        mouse.fill(Path(ellipseIn: CGRect(x: 10, y: -38 - earLift, width: 24, height: 24)), with: .color(LurePalette.yellow))
        mouse.fill(Path(ellipseIn: CGRect(x: 10, y: 14 + earLift, width: 24, height: 24)), with: .color(LurePalette.yellow))
        mouse.fill(Path(ellipseIn: CGRect(x: 24, y: -10, width: 9, height: 9)), with: .color(LurePalette.dark))
        mouse.fill(Path(ellipseIn: CGRect(x: 38, y: -5, width: 10, height: 10)), with: .color(LurePalette.blue))
    }
}

/// Bubbles drift up, wobble, and pop in a flash near the lens. 6s loop.
enum BubblesLure {
    static func draw(in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let lens = LurePalette.lens(in: size)
        let count = 9
        let rise = 3.0
        for i in 0..<count {
            let offset = Double(i) * (6.0 / Double(count))
            let local = (t + offset).truncatingRemainder(dividingBy: 6) / rise
            guard local <= 1 else { continue }
            let startX = size.width * CGFloat(0.12 + 0.76 * Double((i * 37) % 11) / 10)
            let drift = CGFloat(14 * sin(t * 3 + Double(i)))
            let x = startX + (lens.x - startX) * CGFloat(LureMath.easeInOut(local)) + drift
            let y = size.height + 40 - (size.height + 40 - lens.y - 60) * CGFloat(local)
            let radius = CGFloat(18 + 10 * Double(i % 3))
            let center = CGPoint(x: x, y: y)
            if local > 0.92 {
                // Pop: a quick ring flash.
                let pop = (local - 0.92) / 0.08
                context.stroke(LureMath.circle(center, radius * (1 + pop)),
                               with: .color(LurePalette.yellow.opacity(1 - pop)), lineWidth: 4)
            } else {
                context.stroke(LureMath.circle(center, radius), with: .color(LurePalette.blue), lineWidth: 3)
                context.fill(LureMath.circle(CGPoint(x: x - radius * 0.35, y: y - radius * 0.35), radius * 0.2),
                             with: .color(LurePalette.white.opacity(0.9)))
            }
        }
    }
}

/// A paw pokes in from alternating sides, then waves right under the lens. 8s loop.
enum PeekPawLure {
    static func draw(in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let lens = LurePalette.lens(in: size)
        let pawSize = min(size.width, size.height) * 0.3
        let base: CGPoint
        let reach: Double
        let rotation: Double
        switch t {
        case ..<2:
            base = CGPoint(x: -pawSize * 0.2, y: size.height * 0.7)
            reach = LureMath.bump(t / 2)
            rotation = .pi / 2
        case ..<4:
            base = CGPoint(x: size.width + pawSize * 0.2, y: size.height * 0.45)
            reach = LureMath.bump((t - 2) / 2)
            rotation = -.pi / 2
        case ..<5.5:
            base = CGPoint(x: size.width * 0.5, y: size.height + pawSize * 0.2)
            reach = LureMath.bump((t - 4) / 1.5)
            rotation = 0
        default:
            base = CGPoint(x: lens.x, y: lens.y + 60 + pawSize * 0.5)
            reach = 0
            rotation = 0.25 * sin((t - 5.5) * 2 * .pi * 1.5)
        }

        var paw = context
        let direction = CGPoint(x: CGFloat(-sin(rotation)), y: CGFloat(-cos(rotation)))
        let push = CGFloat(reach) * pawSize * 0.9
        paw.translateBy(x: base.x + direction.x * push, y: base.y + direction.y * push)
        paw.rotate(by: .radians(rotation))

        // Pad and four toes, in paw-local coordinates (toes point to -y).
        paw.fill(Path(ellipseIn: CGRect(x: -pawSize * 0.32, y: -pawSize * 0.05, width: pawSize * 0.64, height: pawSize * 0.5)),
                 with: .color(LurePalette.yellow))
        let toes: [CGPoint] = [
            CGPoint(x: -pawSize * 0.34, y: -pawSize * 0.14),
            CGPoint(x: -pawSize * 0.12, y: -pawSize * 0.3),
            CGPoint(x: pawSize * 0.12, y: -pawSize * 0.3),
            CGPoint(x: pawSize * 0.34, y: -pawSize * 0.14),
        ]
        for toe in toes {
            paw.fill(LureMath.circle(toe, pawSize * 0.12), with: .color(LurePalette.blue))
        }
    }
}
