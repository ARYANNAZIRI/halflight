import SwiftUI

enum MarkupKind: String, CaseIterable, Identifiable, Sendable {
    case pen, arrow, circle

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .pen: "Pen"
        case .arrow: "Arrow"
        case .circle: "Circle"
        }
    }

    var symbol: String {
        switch self {
        case .pen: "pencil.tip"
        case .arrow: "arrow.up.right"
        case .circle: "circle"
        }
    }
}

/// Points are unit coordinates of the adjusted image so export and preview agree.
struct MarkupStroke: Identifiable, Equatable, Sendable {
    let id: UUID
    var kind: MarkupKind
    var points: [CGPoint]
    var color: Color

    init(id: UUID = UUID(), kind: MarkupKind, points: [CGPoint], color: Color = Theme.amber) {
        self.id = id
        self.kind = kind
        self.points = points
        self.color = color
    }
}

enum MarkupRenderer {
    /// Path in pixel/point space for a given canvas size, plus the stroke width to use.
    static func path(for stroke: MarkupStroke, in size: CGSize) -> (Path, CGFloat) {
        let width = max(3, min(size.width, size.height) * 0.012)
        func p(_ unit: CGPoint) -> CGPoint { CGPoint(x: unit.x * size.width, y: unit.y * size.height) }
        var path = Path()
        guard let first = stroke.points.first, let last = stroke.points.last else { return (path, width) }
        switch stroke.kind {
        case .pen:
            path.move(to: p(first))
            for point in stroke.points.dropFirst() { path.addLine(to: p(point)) }
        case .arrow:
            let a = p(first), b = p(last)
            path.move(to: a)
            path.addLine(to: b)
            let angle = atan2(b.y - a.y, b.x - a.x)
            let head = max(14, width * 4)
            for spread in [CGFloat.pi / 7, -CGFloat.pi / 7] {
                let tip = CGPoint(x: b.x - cos(angle + spread) * head, y: b.y - sin(angle + spread) * head)
                path.move(to: b)
                path.addLine(to: tip)
            }
        case .circle:
            let a = p(first), b = p(last)
            let rect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
            path.addEllipse(in: rect)
        }
        return (path, width)
    }

    static func draw(_ stroke: MarkupStroke, in context: inout GraphicsContext, size: CGSize) {
        let (path, width) = path(for: stroke, in: size)
        context.stroke(path, with: .color(stroke.color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
}

/// Finger now, Pencil-ready: minimumDistance 0 so a stylus tap registers, no palm logic needed.
struct MarkupCanvas: View {
    @Bindable var model: EditorModel
    let enabled: Bool
    @State private var current: MarkupStroke?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Canvas { context, canvasSize in
                for stroke in model.strokes {
                    MarkupRenderer.draw(stroke, in: &context, size: canvasSize)
                }
                if let current {
                    MarkupRenderer.draw(current, in: &context, size: canvasSize)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        guard size.width > 0, size.height > 0 else { return }
                        let unit = CGPoint(x: value.location.x / size.width, y: value.location.y / size.height)
                        if current == nil {
                            let start = CGPoint(x: value.startLocation.x / size.width, y: value.startLocation.y / size.height)
                            current = MarkupStroke(kind: model.markupKind, points: [start, unit])
                        } else if model.markupKind == .pen {
                            current?.points.append(unit)
                        } else {
                            current?.points = [current?.points.first ?? unit, unit]
                        }
                    }
                    .onEnded { _ in
                        if let current, current.points.count >= 2 {
                            model.strokes.append(current)
                        }
                        current = nil
                    },
                including: enabled ? .all : .subviews
            )
        }
        .allowsHitTesting(enabled)
        .accessibilityLabel(Text("Markup canvas"))
        .accessibilityHint(Text("Draw with a finger or Apple Pencil."))
    }
}

/// Crop rectangle with four corner handles and a draggable interior. 44pt hit targets.
struct CropOverlay: View {
    @Binding var crop: CGRect
    let aspect: CGFloat?
    @State private var startCrop: CGRect?

    private let minSize: CGFloat = 0.12

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let rect = CGRect(x: crop.minX * size.width, y: crop.minY * size.height, width: crop.width * size.width, height: crop.height * size.height)

            ZStack(alignment: .topLeading) {
                Canvas { context, canvasSize in
                    var outside = Path(CGRect(origin: .zero, size: canvasSize))
                    outside.addRect(rect)
                    context.fill(outside, with: .color(.black.opacity(0.55)), style: FillStyle(eoFill: true))
                    context.stroke(Path(rect), with: .color(.white), lineWidth: 1)
                    var grid = Path()
                    for i in 1...2 {
                        let x = rect.minX + rect.width * CGFloat(i) / 3
                        let y = rect.minY + rect.height * CGFloat(i) / 3
                        grid.move(to: CGPoint(x: x, y: rect.minY)); grid.addLine(to: CGPoint(x: x, y: rect.maxY))
                        grid.move(to: CGPoint(x: rect.minX, y: y)); grid.addLine(to: CGPoint(x: rect.maxX, y: y))
                    }
                    context.stroke(grid, with: .color(.white.opacity(0.4)), lineWidth: 0.5)
                }
                .allowsHitTesting(false)

                // Move
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if startCrop == nil { startCrop = crop }
                                guard let start = startCrop else { return }
                                var next = start
                                next.origin.x = min(max(0, start.minX + value.translation.width / size.width), 1 - start.width)
                                next.origin.y = min(max(0, start.minY + value.translation.height / size.height), 1 - start.height)
                                crop = next
                            }
                            .onEnded { _ in startCrop = nil }
                    )

                ForEach(Corner.allCases) { corner in
                    Circle()
                        .fill(Theme.amber)
                        .frame(width: 18, height: 18)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .position(corner.point(in: rect))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if startCrop == nil { startCrop = crop }
                                    guard let start = startCrop else { return }
                                    crop = resize(start, corner: corner, dx: value.translation.width / size.width, dy: value.translation.height / size.height)
                                }
                                .onEnded { _ in startCrop = nil }
                        )
                        .accessibilityLabel(Text("Crop handle"))
                }
            }
        }
    }

    private func resize(_ start: CGRect, corner: Corner, dx: CGFloat, dy: CGFloat) -> CGRect {
        var minX = start.minX, maxX = start.maxX, minY = start.minY, maxY = start.maxY
        switch corner {
        case .topLeading: minX += dx; minY += dy
        case .topTrailing: maxX += dx; minY += dy
        case .bottomLeading: minX += dx; maxY += dy
        case .bottomTrailing: maxX += dx; maxY += dy
        }
        minX = min(max(0, minX), maxX - minSize)
        maxX = max(min(1, maxX), minX + minSize)
        minY = min(max(0, minY), maxY - minSize)
        maxY = max(min(1, maxY), minY + minSize)
        var rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        if let aspect {
            // Keep the requested aspect by adjusting height from width (unit space, so aspect is applied by the caller's image ratio).
            let targetHeight = rect.width / aspect
            if corner == .topLeading || corner == .topTrailing {
                rect.origin.y = rect.maxY - targetHeight
            }
            rect.size.height = targetHeight
            if rect.minY < 0 { rect.origin.y = 0 }
            if rect.maxY > 1 { rect.size.height = 1 - rect.minY; rect.size.width = rect.height * aspect }
        }
        return rect
    }

    enum Corner: CaseIterable, Identifiable {
        case topLeading, topTrailing, bottomLeading, bottomTrailing
        var id: Self { self }

        func point(in rect: CGRect) -> CGPoint {
            switch self {
            case .topLeading: CGPoint(x: rect.minX, y: rect.minY)
            case .topTrailing: CGPoint(x: rect.maxX, y: rect.minY)
            case .bottomLeading: CGPoint(x: rect.minX, y: rect.maxY)
            case .bottomTrailing: CGPoint(x: rect.maxX, y: rect.maxY)
            }
        }
    }
}
