import SwiftUI

/// Records screen, reachable from the menu.
///
/// This view deliberately never touches AdManager. Showing an interstitial for
/// the act of looking at your own stats is the kind of thing that makes people
/// stop opening an app, so entering and leaving here costs nothing.
struct HighScoresView: View {
    @Binding var showHighScores: Bool
    @ObservedObject private var stats = StatsStore.shared

    private let accents: [Int: Color] = [1: .blue, 2: .green, 3: .red]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("High Scores")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .padding(.top, 40)

                Text("Fastest run to \(StatsStore.targetScore) catches")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))

                VStack(spacing: 16) {
                    ForEach(1...3, id: \.self) { level in
                        row(for: level)
                    }
                }
                .padding(.horizontal)

                if !stats.hasAnyRecord {
                    Text("No completed runs yet.\nFinish a game to set a record.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 8)
                }

                Spacer()

                Button("Back") {
                    showHighScores = false
                }
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private func row(for level: Int) -> some View {
        let record = stats.record(for: level)

        VStack(alignment: .leading, spacing: 6) {
            Text(StatsStore.levelName(level))
                .font(.headline)
                .foregroundColor(accents[level] ?? .white)

            if let r = record {
                HStack {
                    Text(StatsStore.timeString(r.bestTime))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Accuracy \(StatsStore.percentString(r.accuracyAtBest))")
                        Text("Best accuracy \(StatsStore.percentString(r.bestAccuracy))")
                        Text("\(r.completions) completed")
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                }
            } else {
                Text("—")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }
}
