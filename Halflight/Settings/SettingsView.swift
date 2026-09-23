import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var settings = app.settings
        NavigationStack {
            Form {
                Section("Camera") {
                    Picker("Default camera", selection: $settings.defaultLens) {
                        Text("Main").tag(CameraSession.Lens.main)
                        Text("Ultra Wide").tag(CameraSession.Lens.ultraWide)
                    }
                    Toggle("Grid", isOn: $settings.gridOn)
                    Toggle("Haptics", isOn: $settings.hapticsOn)
                    Toggle("Auto-Capture when Ready", isOn: $settings.autoCapture)
                }

                Section("Facing") {
                    Picker("Default Facing mode", selection: $settings.defaultFacingMode) {
                        ForEach(FacingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    Toggle("Motion Cue sound", isOn: $settings.cueSoundOn)
                    Toggle("Motion Cue Auto-Capture", isOn: $settings.cueAutoCapture)
                }

                Section("Prompt defaults") {
                    LabeledContent("Speed") {
                        Slider(value: $settings.promptSpeed, in: 20...120, step: 5)
                            .frame(maxWidth: 200)
                            .accessibilityLabel(Text("Prompt speed"))
                    }
                    LabeledContent("Size") {
                        Slider(value: $settings.promptFontSize, in: 28...72, step: 2)
                            .frame(maxWidth: 200)
                            .accessibilityLabel(Text("Prompt text size"))
                    }
                    Toggle("Mirror text", isOn: $settings.promptMirrored)
                }

                Section("Editing") {
                    Toggle("Keep original after edit", isOn: $settings.saveOriginalAndEdit)
                }

                Section {
                    LabeledContent("Halflight Plus") {
                        Text("Later").foregroundStyle(Theme.inkFaint)
                    }
                    .disabled(true)
                    .foregroundStyle(Theme.inkFaint)
                }

                Section {
                    Button("Show onboarding again") { app.settings.resetOnboarding() }
                    NavigationLink("About & Privacy") { AboutView() }
                    #if DEBUG
                    NavigationLink("Developer") { DeveloperView() }
                    #endif
                }
            }
            .scrollContentBackground(.hidden)
            .chromeBackground()
            .navigationTitle("Settings")
            .onChange(of: settings.gridOn) { _, on in app.capture.gridOn = on }
            .onChange(of: settings.autoCapture) { _, on in app.capture.autoCapture = on }
            .onChange(of: settings.promptSpeed) { _, value in app.capture.promptSpeed = value }
            .onChange(of: settings.promptFontSize) { _, value in app.capture.promptFontSize = value }
            .onChange(of: settings.promptMirrored) { _, value in app.capture.promptMirrored = value }
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HalflightMark().scaleEffect(0.5).frame(height: 80)
                    Text("Halflight").font(.title2.weight(.semibold))
                    Text("The other screen is for them.").foregroundStyle(Theme.inkMuted)
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkFaint)
                }
                .listRowBackground(Color.clear)
            }
            Section("Privacy") {
                Text("Everything Halflight captures stays on this phone. There is no account, no analytics, and nothing is uploaded unless you share or save a shot yourself.")
                Text("The outer display only ever shows what you choose for the person in front of the camera: a preview, a cue, a script, or a countdown.")
            }
            Section("Works with iPhone Duo") {
                Text("Facing needs the outer display of iPhone Duo. On other iPhones, Halflight is a camera, a roll, and an editor, and Motion Cue plays full-screen.")
            }
        }
        .scrollContentBackground(.hidden)
        .chromeBackground()
        .navigationTitle("About")
    }
}
