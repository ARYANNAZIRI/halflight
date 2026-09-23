import AVKit
import SwiftUI
import UIKit

/// Camera Control and volume buttons via AVCaptureEventInteraction. Invisible; sits behind the UI.
struct CaptureEventHost: UIViewRepresentable {
    let onPrimary: @MainActor () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        let coordinator = context.coordinator
        let interaction = AVCaptureEventInteraction { event in
            guard event.phase == .began else { return }
            Task { @MainActor in coordinator.onPrimary() }
        }
        interaction.isEnabled = true
        view.addInteraction(interaction)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onPrimary = onPrimary
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPrimary: onPrimary)
    }

    @MainActor
    final class Coordinator {
        var onPrimary: @MainActor () -> Void
        init(onPrimary: @escaping @MainActor () -> Void) { self.onPrimary = onPrimary }
    }
}
