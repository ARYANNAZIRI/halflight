import SwiftUI

#if DEBUG
/// FakeDuo: exercise the whole Facing flow on a normal simulator before hardware arrives.
struct DeveloperView: View {
    @Environment(AppState.self) private var app
    @State private var confirmReset = false

    var body: some View {
        @Bindable var hinge = app.hinge
        Form {
            Section("FakeDuo") {
                Toggle("Simulate iPhone Duo", isOn: $hinge.fake.enabled)
                Picker("Posture", selection: $hinge.fake.posture) {
                    ForEach(DevicePosture.allCases) { posture in
                        Text(posture.title).tag(posture)
                    }
                }
                .disabled(!hinge.fake.enabled)
                Toggle("Accessory available", isOn: $hinge.fake.accessoryAvailable)
                    .disabled(!hinge.fake.enabled)
                Toggle("Show Facing as overlay pane", isOn: $hinge.fake.showFacingOverlay)
                    .disabled(!hinge.fake.enabled)
            }

            Section("Live state") {
                LabeledContent("Duo SDK linked", value: DuoSDK.isLinked ? "Yes" : "No")
                LabeledContent("Is Duo", value: app.hinge.isDuo ? "Yes" : "No")
                LabeledContent("Posture", value: app.hinge.posture.title)
                LabeledContent("Hinge angle", value: app.hinge.angle.map { String(format: "%.0f°", $0) } ?? "—")
                LabeledContent("Facing available", value: app.hinge.facingAvailable ? "Yes" : "No")
                LabeledContent("Facing enabled", value: app.capture.facingEnabled ? "Yes" : "No")
                LabeledContent("Camera status", value: String(describing: app.capture.status))
                LabeledContent("Still Hint", value: String(describing: app.capture.hint))
            }

            Section("Data") {
                LabeledContent("Roll items", value: "\(app.media.items.count)")
                Button("Delete everything in Roll", role: .destructive) { confirmReset = true }
            }
        }
        .scrollContentBackground(.hidden)
        .chromeBackground()
        .navigationTitle("Developer")
        .confirmationDialog("Delete all shots?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Delete all", role: .destructive) { app.media.deleteAll() }
        }
    }
}
#endif
