# Pawlight

**Your pet looks. The shot's already taken.**

Pawlight is a pet camera for iPhone Duo, built on Halflight's camera core. A moving lure plays on
the outer display, facing your pet, and a tap on the sound pad makes them look up. Pawlight watches
for a cat or dog facing the lens and takes the shot by itself (Catch). On any other iPhone the
sounds and Catch still work; only the outer-screen lures need Duo.

- Bundle ID: `app.halflight.pawlight`
- Target and scheme: `Pawlight` / `PawlightTests` in the same `project.yml` as Halflight
- Swift 6, SwiftUI, AVFoundation, Vision, AVAudioEngine, StoreKit 2. Minimum iOS 27.1
- No account, no analytics, no network. Photos stay on the phone.

## How it works

| Piece | File | Notes |
| --- | --- | --- |
| Pet detection | `Pawlight/Detection/PetLook.swift` | `VNRecognizeAnimalsRequest` (cat / dog) plus `VNDetectAnimalBodyPoseRequest` (eyes, nose) on preview frames every 0.1s. |
| "Looking" | `PetLookEvaluator` | Both eyes and the nose visible, the nose between the eyes along the eye line (works at any roll), steady for 0.25s. Pure, unit-tested. |
| Catch | `PetCameraModel.maybeCatch` | Auto-capture on Looking, at most once every 2.5s. Playing a sound arms a one-off catch for 3s even with Catch off. |
| Lures | `Pawlight/Lures/LureDrawings.swift` | Six Canvas animations in blue and yellow, the colours cats and dogs see best. Each loop ends under the outer camera. |
| Sounds | `Pawlight/Lures/SoundSynth.swift` | Squeak, Kiss, Whistle, Chirp, Crinkle, Bell, synthesized on device. Plays through the silent switch. |
| Outer display | `Pawlight/DuoBridge/LureAccessory.swift` | `CameraCaptureAccessory` behind `HALFLIGHT_DUO_SDK`, same as Halflight. FakeDuo overlay in DEBUG. |
| Pro | `Pawlight/Store/ProStore.swift` | One non-consumable, `app.halflight.pawlight.pro`. |

Shared with Halflight (compiled into both apps, listed in `project.yml`): `CameraSession`,
`CameraPreviewView`, `CaptureEventHost`, `StillHint`, the DuoBridge hinge/direction/crease files,
`MediaStore`, and Support. `CameraSession` now takes any `FrameAnalyzer`: Halflight passes its face
`FrameTap`, Pawlight passes `PetFrameAnalyzer`.

## Money

- **Free:** Zip Dot and Bouncy Ball lures, Squeak and Kiss sounds, Catch with one shot.
- **Pawlight Pro, one-time $4.99** (Family Sharing on): all six lures, all six sounds, and up to five
  shots per catch.

In App Store Connect, create the non-consumable `app.halflight.pawlight.pro` with the same price
and attach it to the first build for review. `StoreKit/Pawlight.storekit` lets the `Pawlight`
scheme test purchases in the simulator without App Store Connect. Settings → Developer →
*Pretend Pro* (DEBUG) unlocks everything for screenshots.

## Listing draft

- **Name:** Pawlight: Pet Camera
- **Subtitle:** Lures and sounds for the shot
- **Keywords:** pet,dog,cat,camera,photo,puppy,kitten,treat,squeaky,portrait,foldable,duo
- **Promo:** On iPhone Duo, a lure plays on the outer screen, facing your pet. Pawlight takes the shot when they look.
- **Description (first lines):** Getting a pet to look at the camera is the hard part. Pawlight
  squeaks, chirps and crinkles to get their attention, and on iPhone Duo it plays a moving lure on
  the outer screen, right under the lens. The moment your cat or dog looks at the camera, Pawlight
  takes the shot for you.

## Test plan

- [ ] Point at a dog or cat: badge goes "Looking for a pet" → "Dog spotted" → "Looking!" with a green frame.
- [ ] Catch ON: the photo fires once on Looking, not again within 2.5s. Catch OFF: tapping a sound, then a look within 3s, still fires.
- [ ] Sounds play with the ring switch on silent and don't stop the user's music.
- [ ] Locked lure or sound opens the paywall. Buying in the simulator (StoreKit config) unlocks all, and Restore works.
- [ ] Duo (or FakeDuo): Lure pill toggles the outer display; each lure loops without a jump; closing the phone turns the lure off.
- [ ] Front camera: Lure pill disabled, lure off.
- [ ] Open Duo / regular width: viewfinder left, tools column right, nothing under the crease in book pose.
- [ ] Roll: grid, detail, Save to Photos (add-only permission), Share, Delete.
- [ ] Camera denied: message and Open Settings; no crash.

## Before submitting

- [ ] Real app icon (the committed one is a placeholder paw).
- [ ] Screenshots from the Duo simulator: outer lure + inner viewfinder, "Looking!" moment, sound pad.
- [ ] Confirm the Duo header names once more (see the TODO(duo) comments in Halflight's DuoBridge).
- [ ] Privacy nutrition label: Data Not Collected. Privacy manifest: `Pawlight/Resources/PrivacyInfo.xcprivacy`.
