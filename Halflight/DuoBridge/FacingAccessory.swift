import SwiftUI

/// Wraps `CameraCaptureAccessory` / `.sceneAccessory`. This is the only file that touches the
/// outer-display API. With the Duo SDK flag off, the accessory is a no-op and the DEBUG FakeDuo
/// overlay stands in for the outer display.
struct FacingAccessoryModifier: ViewModifier {
    @Bindable var model: CaptureModel
    let hinge: HingeObserver

    func body(content: Content) -> some View {
        #if HALFLIGHT_DUO_SDK
        content.sceneAccessory {
            CameraCaptureAccessory(isEnabled: $model.facingEnabled) {
                FacingView(model: model)
            }
            .onAvailabilityChange { available in
                hinge.reportAccessoryAvailability(available)
            }
        }
        #else
        content.overlay(alignment: .bottomTrailing) {
            #if DEBUG
            if hinge.fake.enabled, hinge.fake.showFacingOverlay, model.facingEnabled, hinge.facingAvailable {
                FakeOuterDisplayPane(model: model)
                    .padding(12)
                    .transition(.opacity)
            }
            #endif
        }
        #endif
    }
}

extension View {
    func facingAccessory(model: CaptureModel, hinge: HingeObserver) -> some View {
        modifier(FacingAccessoryModifier(model: model, hinge: hinge))
    }
}

#if DEBUG
/// Simulated 5.4-inch outer display, drawn to scale inside the main window.
struct FakeOuterDisplayPane: View {
    let model: CaptureModel

    var body: some View {
        FacingView(model: model)
            .frame(width: 170, height: 170 * (19.5 / 9))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.amber.opacity(0.7), lineWidth: 1.5)
            )
            .overlay(alignment: .top) {
                Text("OUTER")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                    .padding(.top, 4)
            }
            .shadow(radius: 12)
            .allowsHitTesting(false)
    }
}
#endif
