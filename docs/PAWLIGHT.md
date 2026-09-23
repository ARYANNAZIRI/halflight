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

## Listing

The App Store text lives in `fastlane/pawlight/metadata/` (name "Pawlight: Pet Camera", subtitle
"Lures and sounds for the shot", description, keywords, promo text, categories Photo & Video /
Lifestyle, review notes). The landing, privacy and support pages are `docs/pawlight/`, served by the
same GitHub Pages site as Halflight's.

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

## Screenshots without a pet

The simulator has no camera. In a DEBUG build, Settings → Developer → *Screenshot mode: pick a pet
photo* puts any photo in the viewfinder with the "Looking!" badge. Add *Simulate iPhone Duo* and
*Show outer display as overlay* to show a lure next to it, and *Pretend Pro* to unlock every lure.

## App Store Connect checklist

Your Apple account is needed from here; the Developer Program, API key and GitHub secrets from
Halflight's `docs/APP_STORE.md` are reused as they are.

1. **App ID:** Identifiers → **+** → App IDs → explicit `app.halflight.pawlight`, description
   "Pawlight". In-App Purchase is on by default.
2. **App record:** My Apps → **+** → New App: iOS, name **Pawlight: Pet Camera**, English (U.S.),
   bundle ID `app.halflight.pawlight`, SKU `pawlight-ios`.
3. **In-app purchase:** the app → Monetization → In-App Purchases → **+** → Non-Consumable.
   Reference name "Pawlight Pro", product ID `app.halflight.pawlight.pro`, price $4.99,
   Family Sharing on. Display name "Pawlight Pro", description "Every lure and sound, and up to 5
   shots per catch." Add a review screenshot of the paywall (Settings → See what Pro unlocks).
4. **Listing text:** `fastlane ios pawlight_metadata` (same env vars as Halflight's `metadata` lane).
5. **First build:** `fastlane ios pawlight_beta` from your Mac with Xcode 27.1. Once GitHub runners
   have it: Actions → TestFlight → Run workflow → app **pawlight**, or push a `pawlight-v0.1.0` tag.
6. **App Privacy:** Data Not Collected. **Age rating:** 4+. **Price:** Free.
7. **Version page:** screenshots (6.9-inch set; the Duo set when App Store Connect offers it), pick
   the build, and attach the Pawlight Pro purchase under "In-App Purchases and Subscriptions" so it
   is reviewed with the build. Release manually, to time it for October 23.
8. **Submit** by October 14 so review clears before pre-orders open on October 16.

Still open before submitting:

- [ ] Build and run on Xcode 27.1 with the Duo SDK flag on; confirm the `TODO(duo)` names.
- [ ] Try Catch on a real pet.
- [ ] Final app icon (the committed one is a placeholder paw).
