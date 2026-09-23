import SwiftUI

/// Compact width: closed Duo (outer display) and every other iPhone.
/// Single column. Advanced sliders live behind More.
struct CaptureClosedView: View {
    @Bindable var model: CaptureModel
    let level: MotionLevel
    @Binding var showMore: Bool
    let openRoll: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 16)
                .frame(height: 52)

            ViewfinderView(model: model, level: level)
                .aspectRatio(model.mode == .photo ? 3.0 / 4.0 : 9.0 / 16.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)

            Spacer(minLength: 8)

            ModePicker(model: model)
                .padding(.bottom, 4)

            LensChips(model: model)
                .padding(.bottom, 14)

            HStack {
                LastShotThumb(model: model, action: openRoll)
                Spacer()
                ShutterButton(model: model, size: model.handsFree ? Theme.shutterSizeHandsFree : Theme.shutterSize)
                Spacer()
                FlipButton(model: model)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
        .animation(Theme.snap, value: model.mode)
        .animation(Theme.snap, value: model.handsFree)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            if model.isDuo, model.lens != .front, model.hinge.posture != .closed {
                FacingPill(model: model)
            }
            Spacer()
            if model.timer != .off || model.handsFree {
                TimerChip(model: model)
            }
            if model.flash != .off {
                FlashChip(model: model)
            }
            ChromeButton(symbol: "ellipsis", label: "More controls") { showMore = true }
        }
    }
}

#Preview("Closed") {
    let app = AppState()
    CaptureClosedView(model: app.capture, level: MotionLevel(), showMore: .constant(false), openRoll: {})
        .environment(app)
        .preferredColorScheme(.dark)
}
