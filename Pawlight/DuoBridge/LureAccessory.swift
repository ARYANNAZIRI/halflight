import SwiftUI

/// Wraps `CameraCaptureAccessory` / `.sceneAccessory` for Pawlight, same shape as Halflight's
/// `FacingAccessory`. This is Pawlight's only file that touches the outer-display API. With the
/// Duo SDK flag off, the DEBUG FakeDuo overlay pane stands in for the outer display.
struct LureAccessoryModifier: ViewModifier {
    @Bindable var model: PetCameraModel
    let hinge: HingeObserver

    func body(content: Content) -> some View {
        #if HALFLIGHT_DUO_SDK
        content.sceneAccessory {
            CameraCaptureAccessory(isEnabled: $model.lureOn) {
                OuterLureView(model: model)
            }
            .onAvailabilityChange { available in
                hinge.reportAccessoryAvailability(available)
            }
        }
        #else
        content.overlay(alignment: .bottomTrailing) {
            #if DEBUG
            if hinge.fake.enabled, hinge.fake.showFacingOverlay, model.lureIsLive {
                FakeOuterLurePane(model: model)
                    .padding(12)
                    .transition(.opacity)
            }
            #endif
        }
        #endif
    }
}

extension View {
    func lureAccessory(model: PetCameraModel, hinge: HingeObserver) -> some View {
        modifier(LureAccessoryModifier(model: model, hinge: hinge))
    }
}

#if DEBUG
/// Simulated 5.4-inch outer display, drawn to scale inside the main window.
struct FakeOuterLurePane: View {
    let model: PetCameraModel

    var body: some View {
        OuterLureView(model: model)
            .frame(width: 170, height: 170 * (19.5 / 9))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.treat.opacity(0.7), lineWidth: 1.5)
            )
            .overlay(alignment: .top) {
                Text(verbatim: "OUTER")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.treat)
                    .padding(.top, 4)
            }
            .shadow(radius: 12)
            .allowsHitTesting(false)
    }
}
#endif

/// The pet's screen. Only the lure: no text (pets don't read), no settings, never the roll.
struct OuterLureView: View {
    let model: PetCameraModel

    var body: some View {
        LurePlayer(lure: model.lure)
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
    }
}
