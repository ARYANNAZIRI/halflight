import SwiftUI

/// Keeps interactive controls out of the crease while the phone is partially open.
/// System components already avoid the fold on Duo; this covers Halflight's custom chrome.
/// The real reserved-region API, when confirmed, plugs in behind the SDK flag.
struct CreaseAvoiding: ViewModifier {
    let posture: DevicePosture
    /// Fraction of the pane's width reserved around the crease.
    var reserved: CGFloat = 1.0 / 3.0

    func body(content: Content) -> some View {
        #if HALFLIGHT_DUO_SDK
        content // TODO(duo): replace with the SDK reserved-region modifier once confirmed.
        #else
        GeometryReader { proxy in
            let inset = posture.isPartiallyOpen ? proxy.size.width * reserved / 2 : 0
            content
                .padding(.horizontal, inset)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        #endif
    }
}

/// Thin guide drawn where the hinge is, only while partially open. Never interactive.
struct CreaseGuide: View {
    let posture: DevicePosture

    var body: some View {
        if posture.isPartiallyOpen {
            Rectangle()
                .fill(Theme.inkFaint)
                .frame(width: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    func creaseAvoiding(_ posture: DevicePosture) -> some View {
        modifier(CreaseAvoiding(posture: posture))
    }
}
