import Foundation
import GoogleMobileAds
import UIKit

extension Notification.Name {
    static let adWillPresent = Notification.Name("AdManager.adWillPresent")
    static let adDidDismiss  = Notification.Name("AdManager.adDidDismiss")
}

@MainActor
final class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()

    // MARK: - Ad unit

    /// Real interstitial unit for this app. Release builds request against it
    /// directly; the device IDs registered in AppDelegate make it serve test
    /// ads on our own hardware, so there is never a reason to tap a live one.
    private static let productionInterstitialID = "ca-app-pub-2320635595451132/5967571100"

    /// DEBUG uses Google's demo unit, which always fills. A freshly created
    /// AdMob unit answers "No ad to show" for several hours after you make it,
    /// so testing against the real one first thing is indistinguishable from a
    /// broken integration.
    #if DEBUG
    private let interstitialID = "ca-app-pub-3940256099942544/4411468910"
    #else
    private let interstitialID = AdManager.productionInterstitialID
    #endif

    /// A unit ID that was never filled in. Matching on the literal placeholder
    /// keeps this honest — any real ID is all digits after the slash.
    private var adUnitIsPlaceholder: Bool { interstitialID.contains("XXXX") }

    // MARK: - Pacing

    /// Time is the real governor here, not the round count. A round is one
    /// play session, and the game has no game-over — it ends only when the
    /// player taps Stop or Back to Menu — so a round is anything from five
    /// seconds to twenty minutes. Counting them paces nothing reliably. Every
    /// session exit is therefore a candidate, and the gap does the limiting.
    private let minRoundsBetweenAds: Int = 1
    private let minGapSeconds: TimeInterval = 90

    /// Seeded at launch rather than left nil, so `minGapSeconds` gates the
    /// *first* interstitial too. Ungated, someone could install the app, quit
    /// two five-second games and meet a full-screen ad within ten seconds.
    private var lastShown: Date? = Date()
    private var roundsSinceLastAd = 0
    private var interstitial: InterstitialAd?

    private override init() { super.init() }

    // No purchase/remove-ads system in this app yet — always enabled.
    private var adsDisabled: Bool { false }

    // MARK: - Preload

    func preload() {
        guard !adsDisabled else { interstitial = nil; return }
        guard !adUnitIsPlaceholder else {
            print("""
            [AdManager] 🛑 Interstitial unit ID is still the placeholder, so no \
            ad can ever load. Create an interstitial unit in AdMob and paste it \
            into AdManager.productionInterstitialID.
            """)
            return
        }
        guard interstitial == nil else { return }

        InterstitialAd.load(with: interstitialID, request: Request()) { [weak self] ad, error in
            guard let self else { return }
            guard !self.adsDisabled else { return }
            if let ad {
                ad.fullScreenContentDelegate = self
                self.interstitial = ad
                print("[AdManager] ✅ loaded")
            } else {
                print("[AdManager] ❌ load failed: \(error?.localizedDescription ?? "unknown") — retry in 10s")
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.preload() }
            }
        }
    }

    // MARK: - Round tracking

    func noteRoundCompleted() {
        guard !adsDisabled else { return }
        roundsSinceLastAd += 1
    }

    // MARK: - Present

    func presentIfAllowed(completion: ((Bool) -> Void)? = nil) {
        guard !adsDisabled else { completion?(false); return }
        guard UIApplication.shared.applicationState == .active else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.presentIfAllowed(completion: completion)
            }
            return
        }
        guard roundsSinceLastAd >= minRoundsBetweenAds else { completion?(false); return }
        if let last = lastShown, Date().timeIntervalSince(last) < minGapSeconds {
            completion?(false); return
        }
        guard let rootVC = Self.presenterVC() else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.presentIfAllowed(completion: completion)
            }
            return
        }
        guard rootVC.presentedViewController == nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.presentIfAllowed(completion: completion)
            }
            return
        }
        guard let ad = interstitial else { preload(); completion?(false); return }

        ad.present(from: rootVC)
        lastShown = Date()
        roundsSinceLastAd = 0
        interstitial = nil
        preload()
        completion?(true)
    }

    // MARK: - Presenter helpers

    private static func presenterVC() -> UIViewController? {
        if let vc = AdPresenter.holder, vc.viewIfLoaded?.window != nil { return vc }
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        let root = scenes.first?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        return topViewController(base: root)
    }

    private static func topViewController(base: UIViewController?) -> UIViewController? {
        if let nav = base as? UINavigationController { return topViewController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController, let sel = tab.selectedViewController { return topViewController(base: sel) }
        if let presented = base?.presentedViewController { return topViewController(base: presented) }
        return base
    }
}

// MARK: - Delegate

extension AdManager: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: any FullScreenPresentingAd) {
        print("[AdManager] ▶️ presenting")
        NotificationCenter.default.post(name: .adWillPresent, object: nil)
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        // Loud on purpose. A present failure looks identical to a no-fill in
        // the AdMob report except for match rate, and going unlogged is how
        // CoopHockey's 100%-filled rewarded ads served zero impressions for
        // weeks without anyone noticing.
        print("[AdManager] ❌ present failed: \(error.localizedDescription)")
        NotificationCenter.default.post(name: .adDidDismiss, object: nil)
        preload()
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        NotificationCenter.default.post(name: .adDidDismiss, object: nil)
    }
}
