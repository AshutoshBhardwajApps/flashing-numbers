import Foundation

/// Local records, one set per difficulty. Everything stays in UserDefaults on
/// the device — nothing is uploaded, so this adds no privacy or ATT surface.
@MainActor
final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    /// A run ends the moment the player reaches this many catches, which means
    /// the score itself can never be a record — every completed run scores
    /// exactly this. Time is what ranks a run; accuracy is the tiebreaker.
    static let targetScore = 10

    /// Runs are scored on **reaction time only**: the clock runs from the
    /// moment the target appears until it is tapped, and stops in between.
    ///
    /// Wall-clock time was unusable. The target shows up with probability 1/10
    /// per tick, so most of a run is spent waiting rather than reacting, and
    /// that wait is wildly variable. Simulated over 20,000 runs, one player
    /// with zero variation in skill finished level 1 anywhere from 40s to 106s,
    /// while a 60% difference in actual reaction speed moved the mean by under
    /// two seconds — a deliberately sluggish player beat a sharp one 47% of the
    /// time. The table was very nearly a random number generator. Scoring only
    /// the reaction windows drops that to 0%.
    static let wrongTapPenalty: TimeInterval = 0.25

    /// Bumped from `fn.` when scoring moved from wall-clock to reaction time.
    /// Old records are seconds of a completely different quantity — around 70
    /// against the new ~4 — so every first run would have "beaten" them.
    /// Changing the prefix orphans them instead of showing nonsense.
    private static let keyPrefix = "fn2"

    struct Record: Equatable {
        /// Fastest completion, in seconds.
        var bestTime: TimeInterval
        /// Accuracy of that fastest run, 0...1. Kept alongside the time so the
        /// table can show what the record run actually cost in wasted taps.
        var accuracyAtBest: Double
        /// Best accuracy across all completions, which is often a different
        /// (slower, more careful) run than the fastest one.
        var bestAccuracy: Double
        var completions: Int
    }

    @Published private(set) var records: [Int: Record] = [:]

    private init() { load() }

    func record(for level: Int) -> Record? { records[level] }

    var hasAnyRecord: Bool { !records.isEmpty }

    /// Files a completed run. Returns true when it set a new best time, so the
    /// summary screen can celebrate it.
    @discardableResult
    func submit(level: Int, time: TimeInterval, hits: Int, taps: Int) -> Bool {
        let accuracy = taps > 0 ? Double(hits) / Double(taps) : 0

        guard let existing = records[level] else {
            records[level] = Record(bestTime: time,
                                    accuracyAtBest: accuracy,
                                    bestAccuracy: accuracy,
                                    completions: 1)
            save(level: level)
            return true   // a first completion is always a personal best
        }

        let isNewBestTime = time < existing.bestTime
        records[level] = Record(
            bestTime: min(time, existing.bestTime),
            accuracyAtBest: isNewBestTime ? accuracy : existing.accuracyAtBest,
            bestAccuracy: max(accuracy, existing.bestAccuracy),
            completions: existing.completions + 1
        )
        save(level: level)
        return isNewBestTime
    }

    func resetAll() {
        for level in records.keys {
            for key in Self.keys(level: level) {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        records = [:]
    }

    // MARK: - Persistence

    private static func timeKey(_ level: Int) -> String { "\(keyPrefix).best.time.\(level)" }
    private static func accAtBestKey(_ level: Int) -> String { "\(keyPrefix).best.accAtBest.\(level)" }
    private static func accKey(_ level: Int) -> String { "\(keyPrefix).best.acc.\(level)" }
    private static func completionsKey(_ level: Int) -> String { "\(keyPrefix).completions.\(level)" }

    private static func keys(level: Int) -> [String] {
        [timeKey(level), accAtBestKey(level), accKey(level), completionsKey(level)]
    }

    private func save(level: Int) {
        guard let r = records[level] else { return }
        let d = UserDefaults.standard
        d.set(r.bestTime, forKey: Self.timeKey(level))
        d.set(r.accuracyAtBest, forKey: Self.accAtBestKey(level))
        d.set(r.bestAccuracy, forKey: Self.accKey(level))
        d.set(r.completions, forKey: Self.completionsKey(level))
    }

    private func load() {
        let d = UserDefaults.standard
        for level in 1...3 {
            // completions is the presence flag. A stored bestTime of 0 is
            // indistinguishable from "never set" once read back as a Double,
            // so it cannot be the thing that decides whether a record exists.
            let completions = d.integer(forKey: Self.completionsKey(level))
            guard completions > 0 else { continue }
            records[level] = Record(
                bestTime: d.double(forKey: Self.timeKey(level)),
                accuracyAtBest: d.double(forKey: Self.accAtBestKey(level)),
                bestAccuracy: d.double(forKey: Self.accKey(level)),
                completions: completions
            )
        }
    }

    // MARK: - Formatting

    static func levelName(_ level: Int) -> String {
        switch level {
        case 2: return "Level 2 (0.5s)"
        case 3: return "Level 3 (0.25s)"
        default: return "Level 1 (1s)"
        }
    }

    static func timeString(_ t: TimeInterval) -> String {
        String(format: "%.2fs", t)
    }

    static func percentString(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }
}
