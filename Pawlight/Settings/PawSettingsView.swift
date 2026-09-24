import PhotosUI
import SwiftUI

struct PawSettingsView: View {
    @Environment(PawState.self) private var app
    @State private var showPaywall = false

    var body: some View {
        let settings = app.settings
        let pro = app.pro
        NavigationStack {
            Form {
                Section {
                    Toggle("Catch", isOn: Binding(get: { settings.catchOn }, set: { settings.catchOn = $0 }))
                    Stepper(value: Binding(get: { settings.shotsPerCatch }, set: { settings.shotsPerCatch = $0 }), in: 1...5) {
                        HStack {
                            Text("Shots per catch")
                            Spacer()
                            Text("\(pro.isPro ? settings.shotsPerCatch : 1)")
                                .foregroundStyle(Theme.inkMuted)
                                .monospacedDigit()
                        }
                    }
                    .disabled(!pro.isPro)
                } header: {
                    Text("Catch")
                } footer: {
                    Text("Catch takes the photo by itself the moment your pet looks at the camera. Playing a sound arms it for 3 seconds even when it’s off.")
                }

                Section("Sound") {
                    HStack {
                        Image(systemName: "speaker.fill").foregroundStyle(Theme.inkMuted)
                        Slider(value: Binding(get: { settings.soundVolume }, set: { settings.soundVolume = $0 }), in: 0...1)
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(Theme.inkMuted)
                    }
                    Toggle("Haptics", isOn: Binding(get: { settings.hapticsOn }, set: { settings.hapticsOn = $0 }))
                }

                Section("Pawlight Pro") {
                    if pro.isPro {
                        Label("Unlocked. Thank you!", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Theme.ready)
                    } else {
                        Button("See what Pro unlocks") { showPaywall = true }
                        Button("Restore Purchases") {
                            Task { await pro.restore() }
                        }
                    }
                }

                Section {
                    Text("Pawlight has no account, no ads and no analytics. Photos stay on this iPhone until you save or share them. Lure sounds are made on the device.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkMuted)
                } header: {
                    Text("Privacy")
                }

                #if DEBUG
                DeveloperSection()
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(Theme.chrome)
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView()
        }
    }
}

#if DEBUG
/// FakeDuo and a Pro override, so every state runs on a plain simulator.
private struct DeveloperSection: View {
    @Environment(PawState.self) private var app
    @State private var screenshotPick: PhotosPickerItem?

    var body: some View {
        let hinge = app.hinge
        let settings = app.settings
        let camera = app.camera
        Section("Developer") {
            PhotosPicker(selection: $screenshotPick, matching: .images) {
                Text(camera.demoImage == nil ? "Screenshot mode: pick a pet photo" : "Screenshot mode: change photo")
            }
            if camera.demoImage != nil {
                Button("Turn off screenshot mode", role: .destructive) {
                    camera.demoImage = nil
                    screenshotPick = nil
                }
            }
            Toggle("Simulate iPhone Duo", isOn: Binding(get: { hinge.fake.enabled }, set: { hinge.fake.enabled = $0 }))
            if hinge.fake.enabled {
                Picker("Posture", selection: Binding(get: { hinge.fake.posture }, set: { hinge.fake.posture = $0 })) {
                    ForEach(DevicePosture.allCases) { posture in
                        Text(posture.title).tag(posture)
                    }
                }
                Toggle("Accessory available", isOn: Binding(get: { hinge.fake.accessoryAvailable }, set: { hinge.fake.accessoryAvailable = $0 }))
                Toggle("Show outer display as overlay", isOn: Binding(get: { hinge.fake.showFacingOverlay }, set: { hinge.fake.showFacingOverlay = $0 }))
            }
            Toggle("Pretend Pro", isOn: Binding(get: { settings.values.pretendPro }, set: { settings.values.pretendPro = $0 }))
        }
        .onChange(of: screenshotPick) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    camera.demoImage = image
                }
            }
        }
    }
}
#endif
