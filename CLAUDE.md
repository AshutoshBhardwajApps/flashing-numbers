# Claude Conventions for Flashing Numbers

Reaction-time game: tap when the flashing number matches the target, 10
catches per run, scored on reaction time plus 0.25s per wrong tap. Its
infrastructure was brought up to CoopHockey's level in October 2026, and
CoopHockey's `CLAUDE.md` is the longer reference for every pattern below.
`RELEASE_CHECKLIST.md` is the per-release runbook. Read it before any upload.

## Build traps

- **CocoaPods.** Always open `FlashingNumbersV1.xcworkspace`, never the
  `.xcodeproj`, or the build fails with `Framework 'FBAudienceNetwork' not found`.
- `ENABLE_USER_SCRIPT_SANDBOXING = NO` must stay, or "[CP] Copy Pods Resources" dies.
- Command-line builds need `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- **New source files must be added to `project.pbxproj`** (file reference, group
  entry and Sources phase). This project does not use synchronized folders.
- The Meta adapter pod pins Google Mobile Ads at `~> 12.0`. Reaching GMA 13 with
  mediation means moving to SPM, as CoopHockey did. That is a separate job,
  done in Xcode.

## Architecture

- SwiftUI with a UIKit `AppDelegate` adaptor. Screens are switched with `@State`
  flags in `ContentView` (welcome, menu, game, High Scores, Settings), not
  navigation. High Scores and Settings are siblings of the menu, so entering or
  leaving them can never trigger an ad.
- `SettingsStore` and `PurchaseManager` are singletons created as `@StateObject`
  in the App struct and injected with `@EnvironmentObject`. `StatsStore` keeps
  records and stays separate: it is game data, not settings.
- **UserDefaults keys are prefixed `fn.`** in `SettingsStore`.

## Launch order (do not change)

**UMP consent, then ATT, then preload ads**, on `didBecomeActive` plus 0.4s
(`AppDelegate.requestATTIfNeeded`). ATT from `didFinishLaunching` silently
no-ops, which is the bug that got CoopHockey 1.3(14) rejected.
`ConsentManager.gather` always completes (it times out after 5s), so consent
can never block ads.

## Ads (`AdManager`)

- DEBUG uses Google's test interstitial unit, Release uses `...5967571100`.
  Test device hashes live in `AppDelegate`.
- **Pacing is time-based**, unlike CoopHockey. A run can last 5 seconds or 20
  minutes, so the 90s `minGapSeconds` does the limiting, and `lastShown` is seeded
  at launch so the first ad also waits 90s.
- `runAdBreak()` is the one entry point, called when a run finishes or is
  abandoned. It counts the break, then either raises `promoRequested` (a
  forced Remove Ads promo every 8th break, plus random 1-in-12 rolls) or tries
  an interstitial. The promo is a `fullScreenCover` on `ContentView`'s root, so
  "Back to Menu" can't dismiss it.
- Interstitials present from `AdPresenter`'s anchor. Anything inside a sheet or
  cover uses `AdManager.topmostPresenterVC()`.
- `hasRemovedAds` turns off interstitials and promos.

## IAP

- StoreKit 2, one non-consumable: `flashingnumbers.removeads`. It must exist in
  App Store Connect and be attached to the version being submitted.

## Sound + haptics

- `SFX` synthesises the catch, miss and complete sounds at runtime, with no
  audio files. The audio session is `.ambient` with `.mixWithOthers`.
- `SFX` and `Haptics` are both gated by `SettingsStore.effectsEnabled`.

## Versioning

`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` appear twice each in
`project.pbxproj`. Bump the build on every upload, and log releases at the
bottom of `RELEASE_CHECKLIST.md`.

## Not ported yet

- Game Center leaderboards (a best time per level would suit this game).
- Rewarded ads (nothing to earn yet).
- SPM migration and Liftoff/Pangle mediation.

## Style

Terse comments that explain **why**. `// MARK: -` for sections. 4-space indent.
