import Foundation
import SwiftUI

/// Player-facing settings and purchase state, ported from CoopHockey.
///
/// Records and run stats stay in `StatsStore`; this holds only preferences
/// and the Remove Ads flag. Keys are prefixed `fn.` so nothing collides with
/// another app sharing a UserDefaults suite, and each `@Published` field saves
/// itself in `didSet`.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    /// Must match the product ID created in App Store Connect letter-for-letter.
    static let removeAdsProductID = "flashingnumbers.removeads"

    @Published var effectsEnabled: Bool  { didSet { save() } }
    @Published var hasRemovedAds: Bool   { didSet { save() } }

    private init() {
        let d = UserDefaults.standard
        effectsEnabled = d.object(forKey: "fn.effects") as? Bool ?? true
        hasRemovedAds  = d.bool(forKey: "fn.removeAds")
    }

    func markRemoveAdsPurchased() { hasRemovedAds = true }

    private func save() {
        let d = UserDefaults.standard
        d.set(effectsEnabled, forKey: "fn.effects")
        d.set(hasRemovedAds,  forKey: "fn.removeAds")
    }
}
