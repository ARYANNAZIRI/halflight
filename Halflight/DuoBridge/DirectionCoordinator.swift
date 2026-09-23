import AVFoundation
import UIKit
#if HALFLIGHT_DUO_SDK
import AVKit
#endif

/// Resolves which physical camera is "front" right now.
/// On iPhone Duo the virtual front camera already switches between the outer and the
/// under-display inner camera as the phone opens; `AVCaptureDeviceDirectionCoordinator` (AVKit)
/// additionally reports which cameras face forward or backward *relative to a view*, so "front"
/// stays the camera facing the subject when the phone flips. Both are isolated here.
struct CameraDirectionCoordinator: Sendable {
    func frontDevice() -> AVCaptureDevice? {
        // Discovery with position .front resolves to the virtual front camera on iPhone Duo
        // (confirmed in Apple's "Build a great camera experience for iPhone Duo" Tech Talk).
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        )
        return discovery.devices.first
    }

    func rearDevice() -> AVCaptureDevice? {
        // Prefer the dual-wide virtual device so 0.5x ↔ 1x is a zoom change, not an input swap.
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInDualWideCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        return discovery.devices.first
    }
}

/// Which cameras currently face the subject (forward) and the operator (backward), as unique IDs.
struct CameraDirections: Sendable, Equatable {
    var forwardFacingIDs: [String] = []
    var backwardFacingIDs: [String] = []
}

#if HALFLIGHT_DUO_SDK
/// Attaches Apple's direction coordinator to a display view (one per view, as Apple advises)
/// and forwards direction changes on the main actor.
/// Initializer shape confirmed from the Tech Talk: `AVCaptureDeviceDirectionCoordinator(view:deviceTypes:changeHandler:)`.
/// The descriptor → unique ID accessor is the one thing still to confirm against the AVKit header.
@MainActor
final class SubjectDirectionObserver {
    private var coordinator: AVCaptureDeviceDirectionCoordinator?

    init(view: UIView, onChange: @escaping @MainActor (CameraDirections) -> Void) {
        coordinator = AVCaptureDeviceDirectionCoordinator(
            view: view,
            deviceTypes: [.builtInDualWideCamera, .builtInWideAngleCamera, .builtInUltraWideCamera],
            changeHandler: { map in
                // TODO(duo): confirm the descriptor's unique-ID property name in AVKit's header.
                let directions = CameraDirections(
                    forwardFacingIDs: map.forwardFacingDeviceDescriptors.map(\.uniqueID),
                    backwardFacingIDs: map.backwardFacingDeviceDescriptors.map(\.uniqueID)
                )
                Task { @MainActor in onChange(directions) }
            }
        )
    }
}
#endif
