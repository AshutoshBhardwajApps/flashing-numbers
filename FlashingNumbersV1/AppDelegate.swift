import UIKit
import GoogleMobileAds
import AppTrackingTransparency
import AVFAudio

// Meta's adapter is optional here. Guarding the import means the project still
// builds if the mediation pod is not installed, and Meta support switches on by
// itself once it is — no code change needed at that point.
#if canImport(FBAudienceNetwork)
import FBAudienceNetwork
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {

    /// One-shot guard so we only request ATT once per launch even if
    /// didBecomeActive fires multiple times (e.g. user toggled Control
    /// Center, returned to app, etc.).
    private var attRequested = false
    private var didBecomeActiveObserver: NSObjectProtocol?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // SFX plays through AVAudioEngine. .ambient respects the silent switch
        // and mixes with the player's own music instead of stopping it.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            print("Audio session error: \(error)")
        }

        // Register test devices so real ad-unit IDs serve TEST ads on them.
        // Tapping a live ad on your own device is a policy violation that can
        // get the AdMob account suspended, so never test against real fill.
        //
        // The hash below is the one CoopHockey uses. GMA derives it from the
        // IDFV, which is per-vendor rather than per-app, so the same iPhone
        // should hash identically across your apps — but confirm it from the
        // Xcode console on the first ad request and correct it if it differs:
        //   "To get test ads on this device, set: ... testDeviceIdentifiers = @[ @"ABC123..." ]"
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "979fc0c499c82c5211db23733cdf821d", // Ashutosh's iPhone
            // CoopHockey re-read its hash on 2026-10-05 and got this one; the
            // hash follows the advertising ID, so it changes if that's reset.
            // Keep both until the console confirms which this app sees.
            "c18f2644337b99f078c7f88f6136a82f",
        ]

        // Meta Audience Network (mediation bidding) needs its Advertiser
        // Tracking Enabled flag set before the Google Mobile Ads SDK
        // initializes its adapters. On first launch ATT is .notDetermined so
        // this starts false; requestATTIfNeeded() updates it once the user
        // answers the prompt (subsequent launches pick up the stored status).
        setAdvertiserTrackingEnabled(
            ATTrackingManager.trackingAuthorizationStatus == .authorized
        )

        MobileAds.shared.start(completionHandler: nil)

        // ATT must be requested when the app is in the .active state. Calling
        // it from didFinishLaunching is too early — iOS silently no-ops the
        // request and the dialog never shows (App Store 1.3(14) rejection).
        // Defer to didBecomeActive and add a small delay so the launch
        // transition completes before the system alert tries to present.
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.requestATTIfNeeded()
        }

        return true
    }

    private func requestATTIfNeeded() {
        guard !attRequested else { return }
        attRequested = true

        // Stop listening — one-shot.
        if let token = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(token)
            didBecomeActiveObserver = nil
        }

        // 0.4s delay lets the launch transition finish; without it the alert
        // can race with the first frame and either be dropped or appear
        // before the app's UI is visible (which Apple also dislikes).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // UMP consent runs BEFORE ATT, as on CoopHockey. In the
            // EEA/UK/Switzerland a Google-certified CMP has to gather GDPR
            // consent or those users can only ever be served non-personalised
            // ads. Everywhere else UMP reports "no form required" and this
            // falls straight through.
            //
            // Ads are only preloaded once both prompts have been answered, so
            // the first request carries the right consent and ATT signals.
            ConsentManager.shared.gather(from: Self.keyWindowRoot()) { [weak self] in
                self?.requestATTThenPreloadAds()
            }
        }
    }

    private func requestATTThenPreloadAds() {
        ATTrackingManager.requestTrackingAuthorization { [weak self] status in
            self?.setAdvertiserTrackingEnabled(status == .authorized)
            Task { @MainActor in AdManager.shared.preload() }
        }
    }

    /// Root controller of the active scene's key window — where the UMP
    /// consent form presents from. Nothing covers the UI this early in launch.
    private static func keyWindowRoot() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .first?
            .windows.first(where: { $0.isKeyWindow })?
            .rootViewController
    }

    private func setAdvertiserTrackingEnabled(_ enabled: Bool) {
        #if canImport(FBAudienceNetwork)
        FBAdSettings.setAdvertiserTrackingEnabled(enabled)
        #endif
    }
}
