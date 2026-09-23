import SwiftUI

/// Regular width: open Duo (inner display). Viewfinder plus a tools column on the outer edge
/// of the pane so thumbs reach it in 50/50 Split View. Nothing interactive sits over the crease.
struct CaptureOpenView: View {
    @Bindable var model: CaptureModel
    let level: MotionLevel
    @Binding var showMore: Bool
    let openRoll: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                ViewfinderView(model: model, level: level)
                    .padding(12)
                CreaseGuide(posture: model.hinge.posture)
                if model.handsFree {
                    VStack {
                        Spacer()
                        Text("Hands-free")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.amber)
                            .padding(.bottom, 20)
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            toolsColumn
                .frame(width: 112)
                .frame(maxHeight: .infinity)
                .background(Theme.chrome)
        }
        .animation(Theme.snap, value: model.handsFree)
        .animation(Theme.snap, value: model.facingEnabled)
    }

    private var toolsColumn: some View {
        VStack(spacing: 10) {
            if model.isDuo, model.lens != .front {
                FacingPill(model: model)
                if model.facingEnabled {
                    FacingModeStrip(model: model, vertical: false)
                        .frame(maxWidth: 104)
                        .transition(.opacity)
                }
            }

            Spacer(minLength: 4)

            TimerChip(model: model)
            HStack(spacing: 8) {
                FlashChip(model: model)
                ChromeButton(symbol: "ellipsis", label: "More controls") { showMore = true }
            }

            Spacer(minLength: 4)

            ModePicker(model: model, vertical: true)
            LensChips(model: model, vertical: true)

            ShutterButton(model: model, size: model.handsFree ? Theme.shutterSizeHandsFree : Theme.shutterSize)
                .padding(.vertical, 6)

            FlipButton(model: model)
            LastShotThumb(model: model, action: openRoll)
                .padding(.bottom, 12)
        }
        .padding(.top, 12)
        .padding(.horizontal, 6)
    }
}

#Preview("Open", traits: .fixedLayout(width: 1000, height: 740)) {
    let app = AppState()
    CaptureOpenView(model: app.capture, level: MotionLevel(), showMore: .constant(false), openRoll: {})
        .environment(app)
        .environment(\.horizontalSizeClass, .regular)
        .preferredColorScheme(.dark)
}
