import CoreMotion
import Foundation

/// Horizon level from gravity. Works in any interface orientation by snapping to the nearest 90°.
@MainActor @Observable
final class MotionLevel {
    private let manager = CMMotionManager()
    /// Degrees off level, -45...45.
    private(set) var tilt: Double = 0
    private(set) var isActive = false

    var isLevel: Bool { abs(tilt) < 1 }

    func start() {
        guard manager.isDeviceMotionAvailable, !isActive else { return }
        isActive = true
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let gravity = motion.gravity
            let raw = atan2(gravity.x, -gravity.y) * 180 / .pi
            let nearest = (raw / 90).rounded() * 90
            let tilt = raw - nearest
            MainActor.assumeIsolated {
                self?.tilt = tilt
            }
        }
    }

    func stop() {
        guard isActive else { return }
        manager.stopDeviceMotionUpdates()
        isActive = false
        tilt = 0
    }
}
