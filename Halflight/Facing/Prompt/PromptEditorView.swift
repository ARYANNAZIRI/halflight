import SwiftUI

struct PromptEditorView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let script: PromptScript
    @State private var title: String
    @State private var text: String

    init(script: PromptScript) {
        self.script = script
        _title = State(initialValue: script.title)
        _text = State(initialValue: script.body)
    }

    var body: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $title)
            }
            Section("Script") {
                TextEditor(text: $text)
                    .frame(minHeight: 220)
                    .font(.body)
            }
        }
        .scrollContentBackground(.hidden)
        .chromeBackground()
        .navigationTitle("Script")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                    dismiss()
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(role: .destructive) {
                    app.prompts.delete(script)
                    if app.capture.promptScriptID == script.id { app.capture.selectPrompt(nil) }
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .onDisappear(perform: save)
    }

    private func save() {
        var updated = script
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "Untitled") : title
        updated.body = text
        _ = app.prompts.upsert(updated)
    }
}
