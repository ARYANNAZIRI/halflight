import AVFoundation
import SwiftUI
import UIKit

/// Live viewfinder. Several instances can share one session (inner viewfinder + outer Mirror).
struct CameraPreviewView: UIViewRepresentable {
    let source: CameraSession.PreviewSource
    /// Force a mirrored image (what a subject expects to see of themselves).
    var mirrored = false
    /// Called with the tap location in view coordinates and in capture-device coordinates (0...1).
    var onTap: ((CGPoint, CGPoint) -> Void)? = nil
    /// Duo only: which cameras face the subject relative to this view. No-op without the SDK flag.
    var onDirectionsChange: (@MainActor (CameraDirections) -> Void)? = nil

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.attach(source, mirrored: mirrored)
        view.onTap = onTap
        #if HALFLIGHT_DUO_SDK
        if let onDirectionsChange {
            view.directionObserver = SubjectDirectionObserver(view: view, onChange: onDirectionsChange)
        }
        #endif
        return view
    }

    func updateUIView(_ view: PreviewUIView, context: Context) {
        view.attach(source, mirrored: mirrored)
        view.onTap = onTap
    }
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // layerClass guarantees the type; no device query is involved.
        layer as! AVCaptureVideoPreviewLayer
    }

    var onTap: ((CGPoint, CGPoint) -> Void)?

    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var observation: NSKeyValueObservation?
    private var attachedDeviceID: String?
    #if HALFLIGHT_DUO_SDK
    var directionObserver: SubjectDirectionObserver?
    #endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        isAccessibilityElement = true
        accessibilityLabel = String(localized: "Viewfinder")
        accessibilityHint = String(localized: "Double tap to focus.")
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func attach(_ source: CameraSession.PreviewSource, mirrored: Bool) {
        if previewLayer.session !== source.session {
            previewLayer.session = source.session
        }
        if let connection = previewLayer.connection {
            if mirrored {
                if connection.automaticallyAdjustsVideoMirroring { connection.automaticallyAdjustsVideoMirroring = false }
                if connection.isVideoMirroringSupported, !connection.isVideoMirrored { connection.isVideoMirrored = true }
            } else if !connection.automaticallyAdjustsVideoMirroring {
                connection.automaticallyAdjustsVideoMirroring = true
            }
        }
        guard let device = source.device, device.uniqueID != attachedDeviceID else { return }
        attachedDeviceID = device.uniqueID
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotation = coordinator
        apply(angle: coordinator.videoRotationAngleForHorizonLevelPreview)
        observation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelPreview
            Task { @MainActor in self?.apply(angle: angle) }
        }
    }

    private func apply(angle: CGFloat) {
        guard let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        onTap?(point, devicePoint)
    }
}
