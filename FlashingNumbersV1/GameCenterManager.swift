import Foundation
import GameKit
import SwiftUI

/// Game Center: authentication and leaderboard submission, ported from
/// CoopHockey.
///
/// Scope is deliberately narrow — leaderboards only, no achievements and no
/// matchmaking. Authentication is best-effort: a player who declines Game
/// Center, or has no network, must lose nothing. Every submission path is a
/// no-op when unauthenticated rather than an error the player has to see.
@MainActor
final class GameCenterManager: NSObject, ObservableObject {

    static let shared = GameCenterManager()
    private override init() { super.init() }

    /// Leaderboard IDs. These must match the records created in App Store
    /// Connect letter-for-letter, or submissions fail silently.
    ///
    /// All three are "Elapsed Time – To the Hundredth of a Second", sorted
    /// **Low to High**: a lower time is better, the opposite of a points board.
    enum Leaderboard: String, CaseIterable {
        case level1 = "flashingnumbers.leaderboard.besttime.level1"
        case level2 = "flashingnumbers.leaderboard.besttime.level2"
        case level3 = "flashingnumbers.leaderboard.besttime.level3"

        init?(level: Int) {
            switch level {
            case 1: self = .level1
            case 2: self = .level2
            case 3: self = .level3
            default: return nil
            }
        }
    }

    @Published private(set) var isAuthenticated = false

    // MARK: - Authentication

    /// Call once at launch. GameKit presents its own sign-in sheet if needed,
    /// so this must run after there is a window to present from.
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }

                if let viewController {
                    // GameKit wants to show its sign-in UI. Present from the
                    // topmost controller — the plain root may be covered by a
                    // game or a sheet, and UIKit refuses to present from a
                    // controller that is already presenting.
                    Self.topmostViewController()?.present(viewController,
                                                          animated: true)
                    return
                }

                if let error {
                    print("[GameCenter] auth failed: \(error.localizedDescription)")
                    self.isAuthenticated = false
                    return
                }

                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                print("[GameCenter] authenticated=\(self.isAuthenticated)")
                if self.isAuthenticated { self.submitLocalBests() }
            }
        }
    }

    // MARK: - Submission

    /// Records a completed run. Game Center keeps each player's best under
    /// the board's sort order, so submitting a slower time is harmless.
    func recordRunFinished(level: Int, time: TimeInterval) {
        guard let board = Leaderboard(level: level) else { return }
        submit(Self.hundredths(time), to: board)
    }

    /// Re-submits the local records, for runs finished while signed out.
    /// StatsStore already holds the best time per level, so there's no
    /// separate running total to keep here (unlike CoopHockey's win counts).
    private func submitLocalBests() {
        for board in Leaderboard.allCases {
            let level = board == .level1 ? 1 : board == .level2 ? 2 : 3
            if let best = StatsStore.shared.record(for: level)?.bestTime {
                submit(Self.hundredths(best), to: board)
            }
        }
    }

    /// The elapsed-time-to-the-hundredth format takes an integer count of
    /// hundredths of a second.
    private static func hundredths(_ time: TimeInterval) -> Int {
        Int((time * 100).rounded())
    }

    private func submit(_ value: Int, to leaderboard: Leaderboard) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(
            value,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [leaderboard.rawValue]
        ) { error in
            if let error {
                print("[GameCenter] submit to \(leaderboard.rawValue) failed: "
                      + error.localizedDescription)
            }
        }
    }

    // MARK: - Presentation

    /// Opens Game Center's own leaderboard dashboard.
    func showLeaderboards() {
        guard isAuthenticated, let presenter = Self.topmostViewController() else { return }
        let vc = GKGameCenterViewController(state: .leaderboards)
        vc.gameCenterDelegate = self
        presenter.present(vc, animated: true)
    }

    private static func topmostViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .first?
            .windows.first(where: { $0.isKeyWindow })?
            .rootViewController
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

// MARK: - Dashboard dismissal

extension GameCenterManager: GKGameCenterControllerDelegate {
    nonisolated func gameCenterViewControllerDidFinish(
        _ gameCenterViewController: GKGameCenterViewController
    ) {
        Task { @MainActor in
            gameCenterViewController.dismiss(animated: true)
        }
    }
}
