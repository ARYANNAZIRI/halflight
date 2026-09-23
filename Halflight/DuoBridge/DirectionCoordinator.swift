import AVFoundation

/// Resolves which physical camera is "front" right now.
/// On iPhone Duo the virtual front camera already switches between the outer and the
/// under-display inner camera as the phone opens; `AVCaptureDeviceDirectionCoordinator` keeps
/// that binding stable when the phone flips over. Both are isolated here so they can be swapped
/// once headers are confirmed.
struct CameraDirectionCoordinator: Sendable {
    func frontDevice() -> AVCaptureDevice? {
        #if HALFLIGHT_DUO_SDK
        // iOS 27.1 Duo API. Confirm the exact accessor against the SDK header before shipping.
        if let coordinated = AVCaptureDeviceDirectionCoordinator.shared.device(for: .front) {
            return coordinated
        }
        #endif
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
