import SwiftUI

/// A ringed disc turns once every eight seconds. Calm, for older kids and adults. 8s loop.
enum SlowRingCue {
    static func draw(in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.5)
        let radius = min(size.width, size.height) * 0.34
        let angle = 2 * .pi * t / 8

        // Disc
        let disc = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: disc), with: .color(CuePalette.dark))

        // Segmented ring
        let segments = 12
        let ringR = radius * 0.82
        let width = radius * 0.22
        for i in 0..<segments {
            let start = angle + Double(i) * (2 * .pi / Double(segments))
            let end = start + (2 * .pi / Double(segments)) * 0.72
            var path = Path()
            path.addArc(center: center, radius: ringR, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
            context.stroke(path, with: .color(i % 2 == 0 ? CuePalette.amber : CuePalette.cream), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }

        // Marker that sweeps
        let markerR = radius * 0.5
        let marker = CGPoint(x: center.x + cos(angle - .pi / 2) * markerR, y: center.y + sin(angle - .pi / 2) * markerR)
        let dot = CGRect(x: marker.x - radius * 0.09, y: marker.y - radius * 0.09, width: radius * 0.18, height: radius * 0.18)
        context.fill(Path(ellipseIn: dot), with: .color(CuePalette.amber))

        // Centre
        let core = CGRect(x: center.x - radius * 0.12, y: center.y - radius * 0.12, width: radius * 0.24, height: radius * 0.24)
        context.fill(Path(ellipseIn: core), with: .color(CuePalette.cream))
    }
}
