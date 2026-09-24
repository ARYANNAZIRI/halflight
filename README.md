# Halflight

**The other screen is for them.**

Halflight is a camera and director studio for iPhone Duo. The person in front of the phone sees a
preview, a motion cue, or a script on the outer display. You shoot from the inner display. On any
other iPhone it is still a fast camera with a roll, a quick editor, and full-screen Motion Cues.

- Bundle ID: `app.halflight.duo`
- Swift 6, SwiftUI, AVFoundation, Vision, Core Image
- Minimum: iOS 27.1. Built with Xcode 27.1 and the iOS 27.1 SDK
- No account, no analytics SDK, no uploads. Everything stays on the phone.

## Pawlight (sister app)

This repo also builds **Pawlight**, a pet camera for iPhone Duo that reuses Halflight's camera
core: a lure on the outer display, sounds to make pets look, and auto-capture when a cat or dog
faces the lens. Scheme `Pawlight`. See [`docs/PAWLIGHT.md`](docs/PAWLIGHT.md).

## Build

```sh
brew install xcodegen
xcodegen generate
open Halflight.xcodeproj
```

Run the `Halflight` scheme on an iPhone Duo simulator (or a Device Hub device) with Xcode 27.1.
The unit tests (`HalflightTests`) run on any iOS simulator.

### Developing before Duo hardware or headers arrive

1. **FakeDuo** (DEBUG only): Settings → Developer → *Simulate iPhone Duo*. Pick a posture
   (closed / book / tent / open), flip *Accessory available*, and turn on *Show Facing as overlay
   pane* to see the outer-display content as a floating pane inside the main window.
2. **Regular width**: run on a regular-width simulator or use the "Regular" previews to see the
   open-Duo layout (viewfinder + tools column on the outer edge).
3. **Compact width**: any iPhone simulator shows the closed-Duo / standard iPhone layout.

## Duo-only APIs and how they are isolated

All iPhone Duo APIs live in `Halflight/DuoBridge/` behind the `HALFLIGHT_DUO_SDK` compilation
condition. With the flag off (the default), the app compiles against any iOS 27.1 SDK and every
Duo feature degrades cleanly:

| API (iOS 27.1) | Status | File | Off-flag behaviour |
| --- | --- | --- | --- |
| `.sceneAccessory { CameraCaptureAccessory(isEnabled:) { … }.onAvailabilityChange { … } }` | Confirmed (Tech Talk) | `DuoBridge/FacingAccessory.swift` | No accessory. FakeDuo overlay pane stands in. |
| `.onHingeChange { _, context in context.hinge?.status / .angle }` | Confirmed (Tech Talk) | `DuoBridge/HingeObserver.swift` | No hinge reports; `isDuo` stays false unless FakeDuo is on. |
| `AVCaptureDeviceDirectionCoordinator(view:deviceTypes:changeHandler:)` (AVKit) | Confirmed; descriptor accessor to verify | `DuoBridge/DirectionCoordinator.swift` | Front camera from `AVCaptureDeviceDiscoverySession(position: .front)`, which resolves to the virtual front camera on Duo. |
| Reserved regions (`UIView.ReservedRegion`, `reservedRegions`) | Confirmed, UIKit only | `DuoBridge/FoldReservedRegion.swift` | Halflight's own crease-avoidance: primary controls stay out of the middle third while partially open. |
| Split View / multiple scenes | Size classes | `Info.plist` (`UIApplicationSupportsMultipleScenes`) | Layout is driven by size class, so 50/50 Split View just works. |

Sources: Apple Tech Talks "Leverage multiple displays and scenes on iPhone Duo" and "Build a great
camera experience for iPhone Duo" (September 2026). CI enables the flag automatically once the
runner ships an iOS 27.1 SDK; until then only the off-flag path is compiled there.

To turn the real APIs on once the headers are confirmed, set in `project.yml`:

```yaml
HALFLIGHT_DUO_CONDITIONS: "HALFLIGHT_DUO_SDK"
```

then `xcodegen generate`. Each call site under the flag carries a comment asking you to confirm the
exact signature against the SDK header. If a name differs, only that one file changes.

## Structure

```
Halflight/
├── App/            HalflightApp, AppState, RootView (tab bar / rail shell), Theme, EventLog
├── DuoBridge/      DuoCapabilities (posture), HingeObserver (+FakeDuo), FacingAccessory,
│                   DirectionCoordinator, FoldReservedRegion
├── Capture/        CameraSession (actor), CameraPreviewView, CaptureModel, CaptureView,
│                   CaptureClosedView, CaptureOpenView, CaptureControls, StillHint, MotionLevel,
│                   CaptureEventHost (Camera Control / volume shutter)
├── Facing/         FacingMode, FacingView (Mirror / Motion Cue / Prompt / Count / Off),
│                   FacingStudioView, MotionCues/ (six Canvas cues), Prompt/ (scripts + editor)
├── Library/        MediaItem, MediaStore (FileManager + JSON index), RollView, ShotDetailView
├── Edit/           EditorModel, EditorView, ImageAdjust (Core Image), MarkupCanvas + CropOverlay
├── Onboarding/     OnboardingFlow (4 screens, skip-able)
├── Settings/       SettingsStore, SettingsView, DeveloperView (FakeDuo)
├── Support/        Permissions, Haptics, PhotoLibrarySaver, StorageMonitor
└── Resources/      Assets.xcassets, Localizable.xcstrings (English; add Turkish in Project → Info)
```

### Storage

```
Documents/
  Media/    {uuid}.heic | {uuid}.mov
  Thumbs/   {uuid}.jpg
  Scripts/  {uuid}.txt (+ index.json for titles)
Library/Application Support/halflight-index.json   (media metadata)
UserDefaults                                        (settings only, never media)
```

## Threading model

- `CameraSession` is an actor. Everything AVFoundation happens there. Delegates hand back
  Sendable values through an `AsyncStream<Event>`.
- `CaptureModel`, `MediaStore`, `PromptStore`, `SettingsStore`, `HingeObserver` are
  `@MainActor @Observable`.
- File writes, thumbnails, and Core Image renders run in detached tasks.
- The preview layer receives the session through a `@unchecked Sendable` box and only reads it.

## Still Hint and Auto-Capture

`StillHintEvaluator` is a pure value type: a face at least 8% of the frame wide, within ~30° of
frontal, whose centre drifts less than 2% of the frame between samples for 0.6s → **Ready**.
Auto-Capture is off by default and always shows a 2-second warning. For Motion Cue it defaults on,
but only after the animation has played for 2 seconds, and never twice within 4 seconds.

## Copy

Use: Facing, Look here, Motion Cue, Prompt, Ready, Hold still, Saved to Roll, Facing ON.
Never: Kid Cue, Duo Preview, Smart Take, Lumen, or Apple product names in the App Store title.

## Shipping

`docs/APP_STORE.md` is the App Store Connect checklist. Listing text lives in `fastlane/metadata/`,
the privacy manifest in `Halflight/Resources/PrivacyInfo.xcprivacy`, and `fastlane ios beta`
archives with cloud signing and uploads to TestFlight using an App Store Connect API key.
