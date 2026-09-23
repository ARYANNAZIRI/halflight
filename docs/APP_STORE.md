# App Store Connect checklist for Halflight

Everything below the line needs your Apple account. Everything above it is already in the repo.

## Already prepared in this repo

| Item | Where |
| --- | --- |
| Listing text: name, subtitle, description, keywords, promo text, categories, review notes | `fastlane/metadata/` |
| Privacy manifest (required-reason APIs: UserDefaults, disk space; no tracking, no data collected) | `Halflight/Resources/PrivacyInfo.xcprivacy` |
| Privacy policy, support page, landing page | `docs/` (publish with GitHub Pages, below) |
| App icon (1024px) | `Halflight/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` in `project.yml` |
| Upload pipeline | `fastlane/Fastfile` (`beta`, `metadata`), `.github/workflows/testflight.yml` |

App Privacy answers for the "nutrition label": **Data Not Collected**. Halflight has no account, analytics, or network use.

---

## 1. Apple Developer Program (once, ~1 day for approval)

Enroll at https://developer.apple.com/programs/enroll/ ($99/year). You need this before anything else.

## 2. Publish the privacy and support pages (2 minutes)

GitHub → `halflight` → Settings → Pages → Source: **Deploy from a branch**, Branch: **main**, Folder: **/docs** → Save.
After a minute these resolve, and they are the URLs already in the metadata:
- https://aryannaziri.github.io/halflight/privacy.html
- https://aryannaziri.github.io/halflight/support.html

## 3. Register the App ID and the app record (5 minutes)

1. https://developer.apple.com/account/resources/identifiers → **+** → App IDs → App → Bundle ID **explicit** `app.halflight.duo`, description "Halflight". No capabilities needed. Register.
2. https://appstoreconnect.apple.com → My Apps → **+** → New App:
   - Platform iOS, Name **Halflight**, Primary language English (U.S.)
   - Bundle ID `app.halflight.duo`, SKU `halflight-ios`
   - User access: Full Access
3. Note your **Team ID** (Membership details page, 10 characters).

## 4. Create an App Store Connect API key (3 minutes)

App Store Connect → Users and Access → **Integrations** → App Store Connect API → Team Keys → **+**.
Name "Halflight CI", Access **App Manager**. Download the `.p8` once (it cannot be downloaded again). Note the **Key ID** and **Issuer ID**.

## 5. Add the secrets to GitHub (2 minutes)

GitHub → `halflight` → Settings → Secrets and variables → Actions → New repository secret:

| Secret | Value |
| --- | --- |
| `ASC_KEY_ID` | Key ID from step 4 |
| `ASC_ISSUER_ID` | Issuer ID from step 4 |
| `ASC_KEY_P8_BASE64` | `base64 -i AuthKey_XXXX.p8 \| pbcopy` on your Mac, then paste |
| `APPLE_TEAM_ID` | Team ID from step 3 |

## 6. First upload

GitHub's macOS runners do not yet have the iOS 27.1 SDK, so the first uploads happen from your Mac:

```sh
brew install xcodegen fastlane
git clone https://github.com/ARYANNAZIRI/halflight && cd halflight
export ASC_KEY_ID=… ASC_ISSUER_ID=… APPLE_TEAM_ID=…
export ASC_KEY_P8_BASE64=$(base64 -i ~/Downloads/AuthKey_XXXX.p8)
fastlane ios metadata   # pushes the listing text
fastlane ios beta       # archives with cloud signing and uploads to TestFlight
```

Once GitHub runners ship Xcode 27.1, the same secrets let **Actions → TestFlight → Run workflow** do it.

## 7. Finish the listing in App Store Connect

- **Screenshots**: 6.9-inch iPhone set is required, plus an iPhone Duo set once App Store Connect offers the slot. Take them on the simulator with Facing simulated (Settings → Developer). Suggested shots: Capture open with Facing ON, Mirror on the outer pane, a Motion Cue, Prompt, Roll, Editor.
- **App Privacy**: Data Not Collected.
- **Age rating**: answer "None" to every question (4+).
- **Pricing**: Free, all territories.
- **App Review Information**: contact details; notes are pre-filled from `fastlane/metadata/review_information/notes.txt`. No demo account.
- **Version release**: Manually release this version, so you can time it to October 23.

## 8. Submit

Pick the processed TestFlight build on the version page → Add for Review → Submit. Aim to submit by **October 14** so review clears before pre-orders open on October 16.
