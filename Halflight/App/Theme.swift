import SwiftUI

/// Halflight chrome: a calm director's monitor. Black chrome, thin white type,
/// amber reserved for live / recording / Facing ON.
enum Theme {
    static let amber = Color(red: 0xE8 / 255, green: 0xA5 / 255, blue: 0x4B / 255)
    static let amberDeep = Color(red: 0xB8 / 255, green: 0x7A / 255, blue: 0x2A / 255)
    static let navy = Color(red: 0.07, green: 0.09, blue: 0.16)
    static let chrome = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let chromeRaised = Color(white: 0.13)
    static let chromeLine = Color.white.opacity(0.10)
    static let ink = Color.white
    static let inkMuted = Color.white.opacity(0.62)
    static let inkFaint = Color.white.opacity(0.32)
    static let danger = Color(red: 0.95, green: 0.30, blue: 0.25)

    /// Matches the Duo squircle language.
    static let radius: CGFloat = 22
    static let radiusSmall: CGFloat = 12

    /// 200–300ms snaps. No bounce on shutter.
    static let snap: Animation = .easeOut(duration: 0.24)
    static let quick: Animation = .easeOut(duration: 0.18)

    /// Shutter ring: 12mm+ hit target (~76pt at iPhone density).
    static let shutterSize: CGFloat = 76
    static let shutterSizeHandsFree: CGFloat = 104
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
