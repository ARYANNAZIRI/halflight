import SwiftUI

/// Picks the layout by size class (never by UIDevice.orientation) and registers the Duo hooks.
struct CaptureView: View {
    @Environment(AppState.self) private var app
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var level = MotionLevel()
    @State private var showMore = false

    var body: some View {
        let model = app.capture
        Group {
            if hSize == .regular {
                CaptureOpenView(model: model, level: level, showMore: $showMore, openRoll: { app.tab = .roll })
            } else {
                CaptureClosedView(model: model, level: level, showMore: $showMore, openRoll: { app.tab = .roll })
            }
        }
        .chromeBackground()
        .background(CaptureEventHost(onPrimary: { model.shutterTapped() }))
        .hingeReporting(app.hinge)
        .facingAccessory(model: model, hinge: app.hinge)
        .sheet(isPresented: $showMore) {
            MoreControlsSheet(model: model, level: level)
        }
        .task {
            await model.start()
        }
        .onDisappear {
            model.scheduleRelease()
            level.stop()
        }
        .onChange(of: model.facingEnabled) { _, _ in
            model.facingChanged()
        }
        .onChange(of: model.levelOn, initial: true) { _, on in
            if on { level.start() } else { level.stop() }
        }
        .captureAlert(model)
    }
}

extension View {
    func captureAlert(_ model: CaptureModel) -> some View {
        alert(
            model.alert?.title ?? "",
            isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } }),
            presenting: model.alert
        ) { _ in
            Button("OK") {}
        } message: { item in
            Text(item.message)
        }
    }
}
