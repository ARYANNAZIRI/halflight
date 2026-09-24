# Halflight — notes for Claude Code sessions

Halflight is a standalone SwiftUI camera and director studio for iPhone Duo. It is not related to
any other product. Read `README.md` first, then `TESTPLAN.md`.

## Ground rules

- Swift 6 with strict concurrency. `CameraSession` is an actor; models are `@MainActor @Observable`.
- Every iPhone Duo API lives in `Halflight/DuoBridge/` behind the `HALFLIGHT_DUO_SDK` compile
  condition. Never call a Duo API from anywhere else, and keep the off-flag path building.
- Layout is driven by size classes, never `UIDevice.orientation`.
- The outer display (`FacingView` and its children) never shows private UI: no settings, no roll.
- No third-party SDKs, no analytics, no network. `EventLog` is DEBUG-only and local.
- UI copy: use Facing, Look here, Motion Cue, Prompt, Ready, Hold still, Saved to Roll, Facing ON.
  Never use Kid Cue, Duo Preview, Smart Take, Lumen, or Apple product names as feature names.
- No force-unwraps on device or camera queries.

- The repo also holds **Pawlight** (`Pawlight/`, `PawlightTests/`, `docs/PAWLIGHT.md`). It compiles
  some Halflight files directly (listed in `project.yml`), so keep those files free of
  Halflight-only types (`AppState`, `CaptureModel`, `SettingsStore`). Pawlight's Duo API use lives
  in `Pawlight/DuoBridge/` under the same flag.

## Workflow

- Project file is generated: `xcodegen generate` (never hand-edit a `.xcodeproj`).
- Unit tests: `xcodebuild test -scheme Halflight -destination 'platform=iOS Simulator,name=iPhone 17'`
  (any simulator works for the unit tests).
- FakeDuo (Settings → Developer, DEBUG builds) simulates posture and the outer display on a plain
  simulator. Use it before hardware.
- Add new UI strings to `Halflight/Resources/Localizable.xcstrings` (English source; Turkish planned).
