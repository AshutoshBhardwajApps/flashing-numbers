# Release Checklist — Flashing Numbers

## How to use this file

This is the master copy. **Do not tick boxes in it.** For each release, copy it to
`releases/<version>-<build>.md`, tick as you go there, and add a row to the
[Release log](#release-log) at the bottom of *this* file when the version goes live.

```bash
mkdir -p releases && cp RELEASE_CHECKLIST.md releases/1.0.3-5.md
```

Line numbers below are accurate as of build 4 (`a333c09`) and will drift — the symbol
or key name next to each is the reliable part.

### Project facts worth having open

| Thing | Value |
|---|---|
| Bundle ID | `COM.AshutoshBhardwaj.FlashingNumbersV1` |
| App Store ID / SKU | `6745365300` / `flashnum001` |
| Apple Team ID | `78MZ33WP9X` |
| Deployment target | iOS 17.5 |
| AdMob app ID | `ca-app-pub-2320635595451132~1388657149` |
| Production interstitial unit | `ca-app-pub-2320635595451132/5967571100` |
| Repo | `github.com/AshutoshBhardwajApps/flashing-numbers`, branch `main` |
| Dependency manager | CocoaPods — **always open `FlashingNumbersV1.xcworkspace`** |

> **Two traps that have already cost time on this project.** Opening
> `FlashingNumbersV1.xcodeproj` instead of the `.xcworkspace` fails with
> `Framework 'FBAudienceNetwork' not found`, because the bare project never builds the
> Pods targets. And `xcode-select` points at CommandLineTools, so every command-line
> build needs `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

---

## 1. Code & build

- [ ] Bump `MARKETING_VERSION` in `FlashingNumbersV1.xcodeproj/project.pbxproj` (**two
      occurrences** — Debug ~line 408 and Release ~line 442; both must match)
- [ ] Bump `CURRENT_PROJECT_VERSION` in the same file (**two occurrences** — ~line 394
      and ~line 428). App Store Connect rejects a duplicate build number for a version
- [ ] Confirm both edits landed:
      `grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" FlashingNumbersV1.xcodeproj/project.pbxproj`
- [ ] Working tree clean apart from intended changes:
      `git status --short | grep -v "DS_Store\|xcuserstate"`
- [ ] On `main`, and in sync with origin: `git status -sb`
- [ ] Tag the release commit and push the tag —
      `git tag -a v1.0.2-4 -m "1.0.2 (4)" && git push origin v1.0.2-4`
      *(the repo has **no tags at all** today; start here so future releases can diff
      against the last shipped one)*
- [ ] **Production ad unit is in place.** `AdManager.productionInterstitialID`
      (`FlashingNumbersV1/AdManager.swift:19`) reads
      `ca-app-pub-2320635595451132/5967571100`, not a placeholder containing `XXXX`.
      The `adUnitIsPlaceholder` guard at line 33 stops requests if it is, and logs why
- [ ] **The DEBUG test unit has not leaked into Release.** `AdManager.swift:26` sets
      Google's demo unit `ca-app-pub-3940256099942544/4411468910` behind `#if DEBUG`
      only. Verify against the archive, not the source:
      `strings <archive>/Products/Applications/FlashingNumbersV1.app/FlashingNumbersV1 | grep -oE "ca-app-pub-[0-9]+/[0-9]+" | sort -u`
      → must print **only** `ca-app-pub-2320635595451132/5967571100`
- [ ] `GADApplicationIdentifier` still `ca-app-pub-2320635595451132~1388657149`
      (`FlashingNumbersV1/Info.plist:5`)
- [ ] SKAdNetwork IDs present — expect **76** entries including Meta's
      `v9wttpbfk9` and `n38lu8286q`:
      `plutil -p FlashingNumbersV1/Info.plist | grep -c SKAdNetworkIdentifier`
- [ ] `NSUserTrackingUsageDescription` present (`Info.plist:9`) and the wording still
      matches what the ATT prompt should say
- [ ] `ITSAppUsesNonExemptEncryption = false` present (`Info.plist:7`) so App Store
      Connect stops asking the encryption question
- [ ] `FlashingNumbersV1/PrivacyInfo.xcprivacy` is still in **Copy Bundle Resources**
      (not Sources) and lands at the bundle root. Declares
      `NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1` for `StatsStore`. Verify in
      the built app: `ls <app>/PrivacyInfo.xcprivacy`
- [ ] `ENABLE_USER_SCRIPT_SANDBOXING = NO` still set (~lines 302 and 366). With it on,
      CocoaPods' "[CP] Copy Pods Resources" phase is denied writing
      `Pods/resources-to-copy-FlashingNumbersV1.txt` and the build dies with a bare
      "Unexpected failure"
- [ ] `pod install` run if `Podfile` changed; `Podfile.lock` and `Pods/Manifest.lock`
      in sync: `diff -q Podfile.lock Pods/Manifest.lock`
- [ ] Pod versions as expected — Google-Mobile-Ads-SDK 12.4.0, FBAudienceNetwork
      6.21.0, GoogleMobileAdsMediationFacebook 6.21.0.1, GoogleUserMessagingPlatform
      3.0.0. *(The Meta adapter pins GMA to `~> 12.0`, so GMA cannot go to 13.x on
      CocoaPods — moving to SPM is the only way to have both)*
- [ ] Debug-only behaviour off: no `print` spam beyond the intentional `[AdManager]`
      lines, no temporary state in `ContentView` (`showWelcomeView` must be `true`,
      `gameStarted` `false`, `result` with no default value)
- [ ] Clean Release archive succeeds with **no** command-line sandbox override:
      ```
      DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
        -workspace FlashingNumbersV1.xcworkspace -scheme FlashingNumbersV1 \
        -configuration Release -destination "generic/platform=iOS" \
        -archivePath build/FN.xcarchive archive
      ```
- [ ] Archive sanity: version, build, and that every source file actually compiled in —
      `strings <archive>/dSYMs/FlashingNumbersV1.app.dSYM/Contents/Resources/DWARF/FlashingNumbersV1 | grep -oE "^(AdManager|AdPresenter|AppDelegate|ContentView|StatsStore|HighScoresView|App)\.swift" | sort -u`
      *(shipping 1.0.1 with zero ad code went unnoticed because nobody checked this)*
- [ ] **Device smoke test** on a real iPhone via TestFlight:
  - [ ] ATT prompt appears once, shortly after launch, not before the first frame
  - [ ] Play a full run to 10 catches; summary shows time, accuracy, record state
  - [ ] Reaction clock runs **only** while the target is on screen and dims when parked
  - [ ] A missed tap flashes `+0.25s` and the time increases by that much
  - [ ] High Scores persists across an app relaunch
  - [ ] Interstitial actually **presents** (not just loads) — no ad in the first 90s,
        then at most one per 90s (`minRoundsBetweenAds` / `minGapSeconds`,
        `AdManager.swift:42-43`)
  - [ ] The ad shown is a **TEST** ad. Your device hash
        `979fc0c499c82c5211db23733cdf821d` is registered at `AppDelegate.swift:34-36`.
        If a live ad appears the hash is wrong — take the new one from the Xcode console
        (`To get test ads on this device, set: ... testDeviceIdentifiers = @[ ... ]`).
        **Never tap a live ad on your own device**
- [ ] **UMP / consent flow** — ⚠️ `GoogleUserMessagingPlatform` 3.0.0 is installed but
      **no code ever calls it**; there is no consent flow in this app.
      TODO: decide whether to implement UMP before serving EEA/UK traffic, or leave the
      app effectively US-only. Google requires a certified CMP for European users

---

## 2. App Store Connect

- [ ] New version created under the app (`6745365300`)
- [ ] Build uploaded and finished processing — confirm by the
      "has completed processing" email from `no_reply@email.apple.com`, and check it
      carries **no** ITMS warnings (watch for `ITMS-91053` missing API declaration and
      `ITMS-91056` invalid privacy manifest)
- [ ] Correct build attached to the version (double-check the build **number** — builds
      3 and 4 of 1.0.2 differ, only 4 has the privacy manifest and encryption key)
- [ ] **What's New** copy written
- [ ] **Screenshots** for every required size, no alpha channel (Apple rejects alpha):
  - [ ] 6.9" — 1320 × 2868
  - [ ] 6.5" — 1284 × 2778
  - Current set lives at `~/Documents/FlashingNumbers-AppStore-Screenshots/`. Regenerate
    from an iPhone 16 Pro Max simulator with
    `xcrun simctl status_bar <udid> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3`
    then flatten alpha onto black before uploading
- [ ] **App Privacy** labels match what the SDKs declare. Re-derive after any SDK
      change by reading the manifests in the built app
      (`find <app> -name "*.xcprivacy"`). As of build 4:

  | Data type | Purposes | Linked | Tracking |
  |---|---|---|---|
  | Device ID | 3P Advertising, Developer Advertising, Analytics | Yes | **Yes** |
  | Advertising Data | 3P Advertising, Developer Advertising, Analytics | Yes | **Yes** |
  | Product Interaction | 3P Advertising, Developer Advertising, Analytics, App Functionality | Yes | No |
  | Coarse Location | 3P Advertising, Developer Advertising, Analytics, App Functionality | Yes | No |
  | Performance Data | 3P Advertising, Developer Advertising, Analytics, App Functionality | No | No |
  | Other Diagnostic Data | 3P Advertising, Developer Advertising, Analytics | No | No |
  | Crash Data | Analytics | No | No |

- [ ] **Privacy Policy URL** set to `https://ashutoshbhardwajapps.github.io/privacy.html`
      and returning 200: `curl -s -o /dev/null -w "%{http_code}\n" https://ashutoshbhardwajapps.github.io/privacy.html`
- [ ] Privacy policy content still accurate for this release (new SDKs? new data?)
- [ ] **Age rating** questionnaire saved — Advertising **Yes**, everything else No,
      Age Categories and Override **Not Applicable** (never "Made for Kids": the Kids
      Category heavily restricts third-party ads and would break the AdMob integration)
- [ ] **Export compliance** — answered by `ITSAppUsesNonExemptEncryption = false` in
      Info.plist from build 4 onward; only HTTPS via the ad SDKs, which is exempt
- [ ] **In-app purchases** — none in this app (no StoreKit usage anywhere in
      `FlashingNumbersV1/`). Skip unless that changes
- [ ] Pricing and availability unchanged (free, all territories) —
      TODO: confirm whether EEA/UK should stay enabled while there is no UMP consent flow
- [ ] **Review notes** — TODO: state that the app shows interstitial ads at the end of a
      run, that the first ad is withheld for 90 seconds after launch so a reviewer may
      need two runs to see one, and that no login is required
- [ ] **Phased release** — TODO: decide. Recommended **on** for this release, since it is
      the first build that ever serves ads and the first with persistence
- [ ] Submit for review

---

## 3. AdMob

- [ ] Any new or changed ad units created in the AdMob console and pasted into
      `AdManager.swift`. **Leave "Partner bidding" unchecked** — it is for publishers
      using a third-party mediation platform, such units cannot join an AdMob mediation
      group, and the setting is permanent once created
- [ ] App status in AdMob is "Ready" / not restricted, and the app is linked to the App
      Store listing
- [ ] **app-ads.txt live and matching** at
      `https://ashutoshbhardwajapps.github.io/app-ads.txt` — must contain
      `google.com, pub-2320635595451132, DIRECT, f08c47fec0942fa0` and
      `facebook.com, 1467343555157943, DIRECT, c3e20eee3f780d68`
      ```
      curl -s https://ashutoshbhardwajapps.github.io/app-ads.txt
      ```
- [ ] The App Store listing's **Marketing URL** still points at
      `https://ashutoshbhardwajapps.github.io` — AdMob crawls app-ads.txt from the domain
      on the store listing, so if this is blank or changed, verification breaks.
      Note Apple **locks** Marketing URL once a version is "Ready for Distribution", so
      changing it needs a new version *and* a new build
- [ ] AdMob shows app-ads.txt as verified (Apps → Flashing Numbers → app-ads.txt →
      "Check for updates"); allow 24–48h after any listing change
- [ ] **Mediation** — TODO: Meta bidding is compiled in (FBAudienceNetwork 6.21.0) but
      not configured for this app. Needs the app registered and approved in the Meta
      console, then a mediation group and placement mapping in AdMob. When mapping,
      export the placement IDs from Meta and **check the prefix matches the ad space** —
      a mismatched interstitial placement silently blocked all Meta interstitial bids on
      CoopHockey for weeks, and neither console flags it
- [ ] **Test devices** — the registered hash at `AppDelegate.swift:34-36` is deliberate
      and safe to ship; it only forces test ads on that one device. Remove entries for
      devices you no longer own
- [ ] **GDPR / UMP message published** — TODO: no consent flow exists in the app, so
      there is nothing to publish yet. If EEA/UK is enabled, create and publish the
      GDPR message in AdMob **and** implement the UMP call before relying on European
      traffic

---

## 4. Marketing pages

- [ ] Meta/Facebook page post with the new screenshots —
      TODO: page URL
- [ ] Any landing or support page referencing the app updated for this version —
      TODO: there is currently no per-app page; the site
      (`github.com/AshutoshBhardwajApps/AshutoshBhardwajApps.github.io`) holds only
      `README.md`, `app-ads.txt` and `privacy.html`
- [ ] App Store link still resolves:
      `https://apps.apple.com/us/app/flashing-numbers/id6745365300`
- [ ] Screenshots used in marketing match what is actually in the shipped build

---

## 5. Post-release verification (24–72h)

- [ ] **AdMob impressions are non-zero.** A fully-filled ad unit that never presents
      looks identical to healthy fill in the report except for impression count — this
      exact failure ran unnoticed on CoopHockey. Compare requests vs impressions, not
      just match rate
- [ ] eCPM and fill rate in a sane range for the geo mix; no sudden collapse after any
      mediation change
- [ ] Crash-free rate in App Store Connect → Metrics; no new top crash signature
- [ ] Organizer → Crashes reviewed for this build number specifically
- [ ] App Store reviews and ratings checked for complaints about ad frequency —
      pacing is `minRoundsBetweenAds = 1` and `minGapSeconds = 90`
      (`AdManager.swift:42-43`), with the first ad withheld 90s from launch
- [ ] Phased release paused if crash rate or reviews turn bad; resumed once clean
- [ ] Add a row to the [Release log](#release-log) below

---

## Release log

| Version | Build | Date | Notes |
|---|---|---|---|
| 1.0 | 1 | 2025-05-03 | Initial release |
| 1.0.1 | 2 | 2026-07-26 | Marketing URL added so AdMob could crawl app-ads.txt. Contained **no ad code** despite the AdMob SDK being linked |
| 1.0.2 | 4 | TODO: release date | First build that actually serves ads; reaction-time scoring, high scores, run ends at 10 catches. Build 3 was uploaded then superseded by 4, which adds the privacy manifest and export compliance key |

### What went into 1.0.2

Derived from `git log ebc5f89..a333c09` — eleven commits since the 1.0.1 build.

This is the release where the app finally does what the 1.0.1 listing implied. The
AdMob interstitial was wired up against the real unit `...5967571100` and paced by time
rather than round count, since the game has no natural game-over and a round can last
anywhere from five seconds to twenty minutes. The game loop was then rebuilt around a
finish line: a run ends at ten catches, records are kept locally per difficulty in
`StatsStore`, and a High Scores screen hangs off the menu as a sibling of the game so
that viewing your own stats can never trigger an ad. Scoring moved from wall-clock to
reaction time after simulation showed wall-clock was close to a random number generator
— a deliberately sluggish player beat a sharp one 47% of the time, which reaction-only
scoring drops to 0%. Wrong taps now cost 0.25s, which is what stops spam-tapping posting
a perfect score, and a live HUD clock runs only while the target is on screen. Along the
way three real bugs were fixed: a correct tap could be swallowed by a stale pending-miss
state, one game could count as two rounds towards the next ad, and a zero
`minGapSeconds` disabled the ad gap check entirely and fired two interstitials back to
back. Build-side, user script sandboxing was turned off so CocoaPods can build at all,
and the last two commits added the privacy manifest and export compliance declaration.
