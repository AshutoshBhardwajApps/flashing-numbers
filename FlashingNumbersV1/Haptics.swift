import UIKit

/// Tactile feedback for catches, misses and finished runs, ported from
/// CoopHockey. Gated by `SettingsStore.effectsEnabled` and always dispatched to
/// the main thread, which UIFeedbackGenerator requires.
final class Haptics {
    static let shared = Haptics()

    private let lightImpact  = UIImpactFeedbackGenerator(style: .light)
    private let rigidImpact  = UIImpactFeedbackGenerator(style: .rigid)
    private let notify       = UINotificationFeedbackGenerator()

    private init() {
        DispatchQueue.main.async { [self] in
            lightImpact.prepare()
            rigidImpact.prepare()
            notify.prepare()
        }
    }

    /// Tap landed on the target.
    func catchHit() {
        guard SettingsStore.shared.effectsEnabled else { return }
        DispatchQueue.main.async { [self] in
            rigidImpact.impactOccurred(intensity: 0.8)
            rigidImpact.prepare()
        }
    }

    /// Tap off the target — the one that costs time.
    func miss() {
        guard SettingsStore.shared.effectsEnabled else { return }
        DispatchQueue.main.async { [self] in
            notify.notificationOccurred(.error)
            notify.prepare()
        }
    }

    /// Run finished (all catches made).
    func runComplete() {
        guard SettingsStore.shared.effectsEnabled else { return }
        DispatchQueue.main.async { [self] in
            notify.notificationOccurred(.success)
            notify.prepare()
        }
    }
}
