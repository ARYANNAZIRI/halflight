import SwiftUI

#if DEBUG
/// Developer switches so the whole Facing flow can be exercised on a normal simulator.
struct FakeDuo: Codable, Equatable, Sendable {
    var enabled = false
    var posture: DevicePosture = .open
    var accessoryAvailable = true
    /// Renders the Facing content as a floating "outer display" pane inside the main window.
    var showFacingOverlay = true
}
#endif

/// Single source of truth for hinge angle, posture and outer-display availability.
/// Real values arrive through `HingeReporting` (onHingeChange) and the Facing accessory's
/// availability callback. Nothing here ever throws or force-unwraps: on a phone without a
/// hinge, `isDuo` simply stays false.
@MainActor @Observable
final class HingeObserver {
    private(set) var angle: Double?
    private(set) var posture: DevicePosture = .open
    private(set) var hingeReported = false
    private(set) var accessoryEverReported = false
    private(set) var facingAvailable = false

    @ObservationIgnored private let defaults: UserDefaults

    #if DEBUG
    @ObservationIgnored private var fakeStorage: FakeDuo

    var fake: FakeDuo {
        get {
            access(keyPath: \.fake)
            return fakeStorage
        }
        set {
            withMutation(keyPath: \.fake) {
                fakeStorage = newValue
                if let data = try? JSONEncoder().encode(newValue) {
                    defaults.set(data, forKey: "halflight.fakeDuo")
                }
                applyFake()
            }
        }
    }
    #endif

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        if let data = defaults.data(forKey: "halflight.fakeDuo"),
           let stored = try? JSONDecoder().decode(FakeDuo.self, from: data) {
            fakeStorage = stored
        } else {
            fakeStorage = FakeDuo()
        }
        applyFake()
        #endif
    }

    /// True once any Duo-only signal has been seen. Drives "Needs iPhone Duo" states.
    var isDuo: Bool {
        #if DEBUG
        if fake.enabled { return true }
        #endif
        return hingeReported || accessoryEverReported
    }

    var isTent: Bool { posture == .tent }

    // MARK: Inputs

    func reportHinge(angle newAngle: Double) {
        #if DEBUG
        if fake.enabled { return }
        #endif
        hingeReported = true
        angle = newAngle
        let next = DevicePosture.from(angle: newAngle)
        if next != posture { posture = next }
    }

    func reportAccessoryAvailability(_ available: Bool) {
        #if DEBUG
        if fake.enabled { return }
        #endif
        accessoryEverReported = true
        if facingAvailable != available { facingAvailable = available }
    }

    #if DEBUG
    private func applyFake() {
        guard fake.enabled else {
            // Back to real signals; keep whatever the hardware last said.
            if !hingeReported { angle = nil; posture = .open }
            if !accessoryEverReported { facingAvailable = false }
            return
        }
        posture = fake.posture
        angle = fake.posture == .tent ? 105 : (fake.posture == .closed ? 0 : (fake.posture == .book ? 45 : 180))
        facingAvailable = fake.accessoryAvailable && fake.posture != .closed
    }
    #endif
}

// MARK: - onHingeChange bridge

/// Attach once, on the view that owns the camera UI. Forwards hinge angle changes to `HingeObserver`.
struct HingeReporting: ViewModifier {
    let hinge: HingeObserver

    func body(content: Content) -> some View {
        #if HALFLIGHT_DUO_SDK
        // iOS 27.1 Duo API. Confirm the closure signature against the SDK header before shipping.
        content.onHingeChange { change in
            hinge.reportHinge(angle: change.angle)
        }
        #else
        content
        #endif
    }
}

extension View {
    func hingeReporting(_ hinge: HingeObserver) -> some View {
        modifier(HingeReporting(hinge: hinge))
    }
}
