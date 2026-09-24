import SwiftUI

@main
struct PawlightApp: App {
    @State private var app = PawState()

    var body: some Scene {
        WindowGroup {
            PawRootView()
                .environment(app)
        }
    }
}

/// Tab shell. The system tab bar adapts on its own: bottom bar on the outer display and other
/// iPhones, and the iOS 27.1 Duo tab bar on the open inner display.
struct PawRootView: View {
    @Environment(PawState.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.tab) {
            ForEach(PawState.Tab.allCases) { item in
                Tab(item.title, systemImage: item.symbol, value: item) {
                    switch item {
                    case .camera: PetCameraView()
                    case .roll: PetRollView()
                    case .settings: PawSettingsView()
                    }
                }
            }
        }
        .toolbarBackground(Theme.chrome, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
        .tint(Theme.treat)
        .task {
            await app.pro.load()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, app.tab == .camera {
                Task { await app.camera.start() }
            }
        }
        .onChange(of: app.hinge.facingAvailable) { _, available in
            // Accessory went away (phone closed, session ended): flip the lure off, never crash.
            if !available { app.camera.lureOn = false }
        }
        .onChange(of: app.hinge.posture) { _, posture in
            app.camera.postureChanged(posture)
        }
    }
}
