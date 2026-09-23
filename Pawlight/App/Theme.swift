import SwiftUI

/// Pawlight chrome: the same dark camera chrome as Halflight, with a warm treat-yellow accent.
/// Lures use blue and yellow because those are the colours cats and dogs see best.
/// Shared Halflight files (DuoBridge, Capture) read `inkFaint` from here.
enum Theme {
    static let treat = Color(red: 0xFF / 255, green: 0xC8 / 255, blue: 0x3D / 255)
    static let sky = Color(red: 0x3D / 255, green: 0x7B / 255, blue: 0xFF / 255)
    static let chrome = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let chromeRaised = Color(white: 0.13)
    static let chromeLine = Color.white.opacity(0.10)
    static let ink = Color.white
    static let inkMuted = Color.white.opacity(0.62)
    static let inkFaint = Color.white.opacity(0.32)
    static let danger = Color(red: 0.95, green: 0.30, blue: 0.25)
    static let ready = Color(red: 0.36, green: 0.86, blue: 0.52)

    static let radius: CGFloat = 22
    static let radiusSmall: CGFloat = 12

    static let snap: Animation = .easeOut(duration: 0.24)
    static let quick: Animation = .easeOut(duration: 0.18)

    static let shutterSize: CGFloat = 76
    static let minHit: CGFloat = 44
}

extension View {
    /// Dark chrome background that ignores the system color scheme.
    func chromeBackground() -> some View {
        background(Theme.chrome.ignoresSafeArea())
    }
}

struct AlertItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}
