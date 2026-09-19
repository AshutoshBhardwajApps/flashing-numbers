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

    /// Added to the final time for every tap that did not land on the target.
    ///
    /// Misses used to be free, so hammering the screen caught all ten targets
    /// and posted a fast time that measured tapping speed rather than aim.
    /// Charging for them in the currency the run is ranked by makes spamming
    /// strictly worse without forbidding it: a careful run pays a second or
    /// two, a spammed one pays most of a minute.
    static let wrongTapPenalty: TimeInterval = 0.5

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

    private static func keys(level: Int) -> [String] {
        ["fn.best.time.\(level)",
         "fn.best.accAtBest.\(level)",
         "fn.best.acc.\(level)",
         "fn.completions.\(level)"]
    }

    private func save(level: Int) {
        guard let r = records[level] else { return }
        let d = UserDefaults.standard
        d.set(r.bestTime, forKey: "fn.best.time.\(level)")
        d.set(r.accuracyAtBest, forKey: "fn.best.accAtBest.\(level)")
        d.set(r.bestAccuracy, forKey: "fn.best.acc.\(level)")
        d.set(r.completions, forKey: "fn.completions.\(level)")
    }

    private func load() {
        let d = UserDefaults.standard
        for level in 1...3 {
            // completions is the presence flag. A stored bestTime of 0 is
            // indistinguishable from "never set" once read back as a Double,
            // so it cannot be the thing that decides whether a record exists.
            let completions = d.integer(forKey: "fn.completions.\(level)")
            guard completions > 0 else { continue }
            records[level] = Record(
                bestTime: d.double(forKey: "fn.best.time.\(level)"),
                accuracyAtBest: d.double(forKey: "fn.best.accAtBest.\(level)"),
                bestAccuracy: d.double(forKey: "fn.best.acc.\(level)"),
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
