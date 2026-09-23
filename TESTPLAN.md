# Halflight test plan

Run on: iPhone Duo simulator (Xcode 27.1), iPhone Duo hardware via Device Hub, and one non-folding
iPhone (iPhone 18 Pro or similar). Unit tests: `xcodebuild test -scheme Halflight`.

## Launch and permissions

- [ ] First launch shows onboarding; screen 1 cannot be skipped, screens 2–4 can.
- [ ] Launch to Capture in under 1s after the first camera permission grant.
- [ ] Camera denied: Capture shows "Camera access is off" with an Open Settings button, no crash.
- [ ] Microphone denied: video still records (silent), photos unaffected.
- [ ] Photo Library denied: shots still land in Roll; Save to Photos shows a clear error.

## Duo posture and Facing

- [ ] Closed Duo / normal iPhone: no Facing pill, no crash, Facing tab says "Needs iPhone Duo".
- [ ] Open Duo + rear camera: Facing pill enabled, accessory available, Mirror appears on the outer display.
- [ ] Mirror: the subject sees a mirrored preview and "Look here"; countdown shows when a timer runs.
- [ ] Motion Cue: each of the six cues loops seamlessly (8–12s); tap on the inner screen cycles cues; Mix shuffles every 10s.
- [ ] Prompt: load a script, play from the inner screen, text scrolls on the outer screen; speed, size, mirror toggle apply live; Restart resets.
- [ ] Count: 3-2-1 on the outer display, amber wash on "1", the captured photo shows for 1.5s.
- [ ] Off: the outer display stays unused.
- [ ] Close mid-preview: accessory becomes unavailable, Facing toggle flips off, the rear session keeps running, the last shot is still in Roll.
- [ ] Flip the device (upside-down): front camera identity stays correct, preview orientation follows.
- [ ] Switch to the front camera: Facing pill hides (outer display faces away from the subject).
- [ ] Tent angle (~80–130°): hands-free mode starts (large shutter, 3s timer when timer is Off), "Hold still" on the facing display, and the shutter is never under the crease.
- [ ] Book pose: no primary button in the middle third.
- [ ] FakeDuo (DEBUG): every state above reproducible on a plain simulator via Settings → Developer.

## Split View and size classes

- [ ] Split View 50/50 with Capture: shutter still tappable on the outer edge of the pane.
- [ ] Split View 50/50 with Roll: grid readable, detail opens in the other column.
- [ ] Rotation on the inner display: portrait and landscape both lay out with no clipped buttons.
- [ ] Outer display: portrait-first single column; advanced sliders only behind More.

## Capture

- [ ] Photo: HEIF written, thumbnail generated, "Saved to Roll" toast, shutter haptic.
- [ ] Burst: 5 shots, all in Roll.
- [ ] Timer 3s / 10s: countdown on the viewfinder, tap the shutter again cancels.
- [ ] Zoom: 1x and 2x chips; pinch below 1x switches to Ultra Wide (dual-wide modules only).
- [ ] Tap-to-focus shows a reticle; exposure slider in More applies live; torch toggles.
- [ ] Video: 4K where supported, HDR when the format allows, recording badge counts up.
- [ ] Record 60s, background the app: recording stops cleanly and the file appears in Roll.
- [ ] Incoming call / Control Center: "The camera paused" banner, resumes when the interruption ends.
- [ ] Leaving Capture for more than 3s releases the session; returning restarts within 1s.
- [ ] Camera Control / volume button takes a photo.
- [ ] Low storage (< 300 MB): alert before recording, no crash.

## Still Hint

- [ ] One frontal, steady face for ~0.6s pulses "Ready".
- [ ] Auto-Capture (off by default): "Auto in 2 / 1" warning, shot fires only if still Ready.
- [ ] Motion Cue Auto-Capture: never before the cue has played 2s; never twice within 4s.
- [ ] Turned-away or tiny faces never trigger Ready.

## Roll and Edit

- [ ] Filters: All / Photos / Videos / Saved.
- [ ] Sessions group shots; a new session starts after 30 minutes idle.
- [ ] Swipe up saves to Photos (asks add-only permission once), swipe down asks to delete.
- [ ] Share sheet works for photos and videos.
- [ ] Editor: crop with aspect presets, rotate, exposure / contrast / warmth, arrow / circle / pen markup.
- [ ] Before / after: hold the toggle to see the original.
- [ ] Export: Save to Roll (keeps the original when the setting is on), Save to Photos, Share, Copy.
- [ ] Open Duo: editor uses the full inner canvas, no letterboxing. Closed: standard editor.

## Accessibility and polish

- [ ] VoiceOver: can take a photo, switch camera, change Facing mode, and read the countdown.
- [ ] Dynamic Type applies in Settings and the Prompt editor, not in Motion Cue.
- [ ] Capture chrome stays dark in light mode.
- [ ] Empty states: Roll, Edit tab, no script.
- [ ] Motion Cue runs at 60fps on the outer display without dropping the inner viewfinder (Instruments: Core Animation FPS).

## Unit tests (HalflightTests)

- StillHintEvaluatorTests: ready timing, motion reset, no-face, yaw and size filters.
- DevicePostureTests: hinge angle → posture boundaries.
- MediaStoreTests: photo write + thumb, index reload, delete, session grouping, HEIF sniffing.
- PromptStoreTests: seeds, create / duplicate / delete, clipboard import.
- SettingsStoreTests: persistence; FakeDuo drives posture and availability (DEBUG).
