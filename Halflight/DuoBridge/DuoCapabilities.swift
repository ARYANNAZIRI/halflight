import Foundation

/// Compile-time switch for the iOS 27.1 iPhone Duo APIs.
/// Set `HALFLIGHT_DUO_CONDITIONS = HALFLIGHT_DUO_SDK` in project.yml once the headers are confirmed.
enum DuoSDK {
    #if HALFLIGHT_DUO_SDK
    static let isLinked = true
    #else
    static let isLinked = false
    #endif
}

/// Physical posture derived from the hinge angle. Size classes stay the source of truth for
/// layout; posture only drives hands-free mode and crease avoidance.
enum DevicePosture: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Folded shut. Outer display only.
    case closed
    /// Slightly open, held like a book. Inner display, crease is live.
    case book
    /// Tent range (~80–130°). Hands-free capture.
    case tent
    /// Flat or nearly flat. Full inner canvas.
    case open

    var id: String { rawValue }

    static let tentRange: ClosedRange<Double> = 80...130
    static let closedBelow: Double = 15

    static func from(angle: Double) -> DevicePosture {
        if angle < closedBelow { return .closed }
        if angle < tentRange.lowerBound { return .book }
        if tentRange.contains(angle) { return .tent }
        return .open
    }

    /// True when the crease is a real obstacle for primary controls.
    var isPartiallyOpen: Bool {
        switch self {
        case .book, .tent: true
        case .closed, .open: false
        }
    }

    var title: String {
        switch self {
        case .closed: "Closed"
        case .book: "Book"
        case .tent: "Tent"
        case .open: "Open"
        }
    }
}
