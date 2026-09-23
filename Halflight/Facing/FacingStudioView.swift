import SwiftUI
import UIKit

/// The Facing tab: pick the mode, tune it, turn it on. Everything here stays on the inner display.
struct FacingStudioView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var model = app.capture
        @Bindable var settings = app.settings
        NavigationStack {
            List {
                Section {
                    Text("The other screen is for them.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .listRowBackground(Color.clear)
                }

                if model.isDuo {
                    Section {
                        Toggle("Facing ON", isOn: $model.facingEnabled)
                            .disabled(!model.facingAvailable || model.facingMode == .off)
                            .tint(Theme.amber)
                        if !model.facingAvailable {
                            Label("Open the phone and use the rear camera to turn Facing on.", systemImage: "info.circle")
                                .font(.footnote)
                                .foregroundStyle(Theme.inkMuted)
                        }
                    }
                } else {
                    Section {
                        Label("Needs iPhone Duo", systemImage: "iphone.gen3.slash")
                            .foregroundStyle(Theme.ink)
                        Text("Facing puts a preview, a cue, or a script on the outer display. On this phone you can still play a Motion Cue full-screen.")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkMuted)
                        Button("Play Motion Cue here") { model.showCueOverlay(true) }
                    }
                }

                Section("Mode") {
                    ForEach(FacingMode.allCases) { mode in
                        Button {
                            model.setFacingMode(mode)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: mode.symbol)
                                    .font(.system(size: 18, weight: .medium))
                                    .frame(width: 28)
                                    .foregroundStyle(model.facingMode == mode ? Theme.amber : Theme.ink)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.title).foregroundStyle(Theme.ink)
                                    Text(mode.summary).font(.footnote).foregroundStyle(Theme.inkMuted)
                                }
                                Spacer()
                                if model.facingMode == mode {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.amber)
                                }
                            }
                        }
                        .accessibilityAddTraits(model.facingMode == mode ? [.isSelected] : [])
                    }
                }

                switch model.facingMode {
                case .mirror:
                    Section("Mirror") {
                        Toggle("Show countdown", isOn: $model.mirrorCountdown)
                        Toggle("Pose silhouette", isOn: $model.showPoseSilhouette)
                    }
                case .motionCue:
                    Section("Motion Cue") {
                        CuePickerGrid(model: model)
                            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                        Toggle("Mix (shuffle every 10s)", isOn: Binding(get: { model.mixCues }, set: { model.setMixCues($0) }))
                        Toggle("Sound", isOn: $settings.cueSoundOn)
                        Toggle("Auto-Capture after 2 seconds", isOn: $settings.cueAutoCapture)
                        if !model.isDuo {
                            Button("Play here") { model.showCueOverlay(true) }
                        }
                    }
                case .prompt:
                    PromptSections(model: model)
                case .count:
                    Section("Count") {
                        Text("A large countdown on the outer display, an amber wash just before the shutter, then the shot for a moment so they know it happened.")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkMuted)
                    }
                case .off:
                    EmptyView()
                }
            }
            .scrollContentBackground(.hidden)
            .chromeBackground()
            .navigationTitle("Facing")
        }
    }
}

struct CuePickerGrid: View {
    let model: CaptureModel

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
            ForEach(MotionCue.allCases) { cue in
                Button {
                    model.setCue(cue)
                } label: {
                    VStack(spacing: 6) {
                        MotionCuePlayer(cue: cue)
                            .frame(height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                    .stroke(model.cue == cue ? Theme.amber : .clear, lineWidth: 2)
                            )
                        Text(cue.title)
                            .font(.caption)
                            .foregroundStyle(model.cue == cue ? Theme.amber : Theme.inkMuted)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(cue.title))
                .accessibilityAddTraits(model.cue == cue ? [.isSelected] : [])
            }
        }
    }
}

/// Prompt controls for the inner display: play / pause, speed, size, mirror, scripts.
struct PromptSections: View {
    @Bindable var model: CaptureModel
    @Environment(AppState.self) private var app

    var body: some View {
        Section("Prompt") {
            HStack(spacing: 12) {
                Button {
                    model.togglePrompt()
                } label: {
                    Label(model.promptPlaying ? "Pause" : "Play", systemImage: model.promptPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    model.restartPrompt()
                } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
            .listRowBackground(Color.clear)

            LabeledContent("Speed") {
                Slider(value: $model.promptSpeed, in: 20...120, step: 5)
                    .frame(maxWidth: 220)
                    .accessibilityLabel(Text("Prompt speed"))
            }
            LabeledContent("Size") {
                Slider(value: $model.promptFontSize, in: 28...72, step: 2)
                    .frame(maxWidth: 220)
                    .accessibilityLabel(Text("Prompt text size"))
            }
            Toggle("Mirror text", isOn: $model.promptMirrored)
        }

        Section("Scripts") {
            ForEach(app.prompts.scripts) { script in
                HStack {
                    Button {
                        model.selectPrompt(script)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(script.title).foregroundStyle(Theme.ink)
                                Text(script.body.isEmpty ? String(localized: "Empty") : script.body)
                                    .lineLimit(1)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.inkMuted)
                            }
                            Spacer()
                            if model.promptScriptID == script.id {
                                Image(systemName: "checkmark").foregroundStyle(Theme.amber)
                            }
                        }
                    }
                    NavigationLink {
                        PromptEditorView(script: script)
                    } label: {
                        EmptyView()
                    }
                    .frame(width: 20)
                    .accessibilityLabel(Text("Edit script"))
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        if model.promptScriptID == script.id { model.selectPrompt(nil) }
                        app.prompts.delete(script)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        _ = app.prompts.duplicate(script)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    .tint(Theme.amberDeep)
                }
            }
            Button {
                let script = app.prompts.create()
                model.selectPrompt(script)
            } label: {
                Label("New script", systemImage: "plus")
            }
            Button {
                if let script = app.prompts.importFromClipboard(text: UIPasteboard.general.string) {
                    model.selectPrompt(script)
                }
            } label: {
                Label("Paste from clipboard", systemImage: "doc.on.clipboard")
            }
        }
    }
}
