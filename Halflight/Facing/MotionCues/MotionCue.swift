import SwiftUI

/// Six original cues. No licensed characters, no video files: each one is drawn in Canvas
/// from a time value, so the loop is seamless and cheap on the outer display.
enum MotionCue: String, CaseIterable, Codable, Identifiable, Sendable {
    case emberOrb, hideSeek, liftDots, slowRing, softBlob, inwardPulse

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .emberOrb: "Ember Orb"
        case .hideSeek: "Hide & Seek"
        case .liftDots: "Lift Dots"
        case .slowRing: "Slow Ring"
        case .softBlob: "Soft Blob"
        case .inwardPulse: "Inward Pulse"
        }
    }

    var symbol: String {
        switch self {
        case .emberOrb: "circle.fill"
        case .hideSeek: "eye"
        case .liftDots: "circle.grid.3x3"
        case .slowRing: "circle.circle"
        case .softBlob: "face.smiling"
        case .inwardPulse: "square.on.square"
        }
    }

    /// Seamless loop length in seconds (8–12).
    var loopDuration: TimeInterval {
        switch self {
        case .emberOrb: 12
        case .hideSeek: 8
        case .liftDots: 10
        case .slowRing: 8
        case .softBlob: 8
        case .inwardPulse: 12
        }
    }

    var next: MotionCue {
        let all = MotionCue.allCases
        guard let index = all.firstIndex(of: self) else { return .emberOrb }
        return all[(index + 1) % all.count]
    }

    /// Beats (seconds into the loop) where an optional sound may tick.
    var beats: [TimeInterval] {
        switch self {
        case .emberOrb: [0, 3, 6, 9]
        case .hideSeek: [0, 4]
        case .liftDots: [1, 2, 3, 4, 5]
        case .slowRing: [0]
        case .softBlob: [0, 4]
        case .inwardPulse: [0, 3, 6, 9]
        }
    }
}
