import SwiftUI

/// What plays on the outer display to pull a pet's eyes to the lens.
/// Every lure is drawn in Canvas from a time value: no video files, seamless loops, and each
/// loop ends its motion near the top centre, where the outer camera is.
enum Lure: String, CaseIterable, Codable, Identifiable, Sendable {
    case zipDot, bouncyBall, feather, mouse, bubbles, peekPaw

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .zipDot: "Zip Dot"
        case .bouncyBall: "Bouncy Ball"
        case .feather: "Feather"
        case .mouse: "Mouse"
        case .bubbles: "Bubbles"
        case .peekPaw: "Peek Paw"
        }
    }

    var symbol: String {
        switch self {
        case .zipDot: "smallcircle.filled.circle"
        case .bouncyBall: "circle.fill"
        case .feather: "leaf"
        case .mouse: "hare"
        case .bubbles: "bubbles.and.sparkles"
        case .peekPaw: "pawprint"
        }
    }

    /// Seamless loop length in seconds.
    var loopDuration: TimeInterval {
        switch self {
        case .zipDot: 6
        case .bouncyBall: 4
        case .feather: 6
        case .mouse: 8
        case .bubbles: 6
        case .peekPaw: 8
        }
    }

    /// Free lures. Everything else needs Pawlight Pro.
    var isFree: Bool {
        switch self {
        case .zipDot, .bouncyBall: true
        case .feather, .mouse, .bubbles, .peekPaw: false
        }
    }

    var next: Lure {
        let all = Lure.allCases
        guard let index = all.firstIndex(of: self) else { return .zipDot }
        return all[(index + 1) % all.count]
    }
}

/// Short sounds that make a pet look up. Synthesized on device (see `SoundSynth`), so the app
/// ships no audio files and every sound loops cleanly at any volume.
enum LureSound: String, CaseIterable, Codable, Identifiable, Sendable {
    case squeak, kiss, whistle, chirp, crinkle, bell

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .squeak: "Squeak"
        case .kiss: "Kiss"
        case .whistle: "Whistle"
        case .chirp: "Chirp"
        case .crinkle: "Crinkle"
        case .bell: "Bell"
        }
    }

    var symbol: String {
        switch self {
        case .squeak: "circle.dotted"
        case .kiss: "mouth"
        case .whistle: "wind"
        case .chirp: "bird"
        case .crinkle: "bag"
        case .bell: "bell"
        }
    }

    var isFree: Bool {
        switch self {
        case .squeak, .kiss: true
        case .whistle, .chirp, .crinkle, .bell: false
        }
    }
}
