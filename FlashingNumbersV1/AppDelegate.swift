import UIKit
import GoogleMobileAds
import AppTrackingTransparency

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            ATTrackingManager.requestTrackingAuthorization { status in
                self?.setAdvertiserTrackingEnabled(status == .authorized)
                Task { @MainActor in AdManager.shared.preload() }
            }
        }
    }

    private func setAdvertiserTrackingEnabled(_ enabled: Bool) {
        #if canImport(FBAudienceNetwork)
        FBAdSettings.setAdvertiserTrackingEnabled(enabled)
        #endif
    }
}
