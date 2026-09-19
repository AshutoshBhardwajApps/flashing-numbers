// Entry point with screen switching
import SwiftUI

struct ContentView: View {
    @State private var showWelcomeView = true
    @State private var gameStarted = false
    @State private var showHighScores = false
    @State private var selectedLevel = 1

    var body: some View {
        if showWelcomeView {
            WelcomeView(showWelcomeView: $showWelcomeView)
        } else if gameStarted {
            GameView(selectedLevel: selectedLevel, gameStarted: $gameStarted)
        } else if showHighScores {
            // A sibling of the menu rather than a screen reached through the
            // game, so nothing on the way in or out can trigger an ad.
            HighScoresView(showHighScores: $showHighScores)
        } else {
            IntroScreen(gameStarted: $gameStarted,
                        selectedLevel: $selectedLevel,
                        showHighScores: $showHighScores)
        }
    }
}

struct IntroScreen: View {
    @Binding var gameStarted: Bool
    @Binding var selectedLevel: Int
    @Binding var showHighScores: Bool

    var body: some View {
        VStack(spacing: 40) {
            Text("Select a Level")
                .font(.largeTitle)
                .foregroundColor(Color.primary)
                .padding()

            Button("Level 1 (1s)") {
                selectedLevel = 1
                gameStarted = true
            }
            .padding().background(Color.blue).foregroundColor(.white).cornerRadius(10)

            Button("Level 2 (0.5s)") {
                selectedLevel = 2
                gameStarted = true
            }
            .padding().background(Color.green).foregroundColor(.white).cornerRadius(10)

            Button("Level 3 (0.25s)") {
                selectedLevel = 3
                gameStarted = true
            }
            .padding().background(Color.red).foregroundColor(.white).cornerRadius(10)

            Button("High Scores") {
                showHighScores = true
            }
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
}

struct WelcomeView: View {
    @Binding var showWelcomeView: Bool
    @State private var animate = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            NumberRainView()
            VStack(spacing: 20) {
                Spacer()
                Text("Flashing Numbers")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                Spacer()
                Text("Tap to Start")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
            }
        }
        .onTapGesture {
            showWelcomeView = false
        }
    }
}

struct NumberRainView: View {
    @State private var animate = false
    @State private var drops: [RainDrop] = []

    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan]

    struct RainDrop: Identifiable {
        let id = UUID()
        let number: Int
        let xPosition: CGFloat
        let duration: Double
        let delay: Double
        let color: Color
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(drops) { drop in
                    Text("\(drop.number)")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(drop.color.opacity(0.8))
                        .position(x: drop.xPosition,
                                  y: animate ? geometry.size.height + 50 : -50)
                        .opacity(0.9)
                        .animation(
                            Animation.linear(duration: drop.duration)
                                .repeatForever()
                                .delay(drop.delay),
                            value: animate
                        )
                }
            }
            .clipped()
            .onAppear {
                let width = geometry.size.width
                let numbers = Array(repeating: Array(1...10), count: 2).flatMap { $0 }
                drops = numbers.enumerated().map { (index, num) in
                    RainDrop(
                        number: num,
                        xPosition: CGFloat.random(in: 0...(width - 20)),
                        duration: Double.random(in: 6.0...9.0),
                        delay: Double(index) * 0.15,
                        color: colors.randomElement() ?? .white
                    )
                }

                DispatchQueue.main.async {
                    animate = true
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct GameView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var currentNumber: Int = 0
    @State private var targetNumber: Int = Int.random(in: 1...10)
    @State private var score: Int = 0
    @State private var missTime: Double? = nil
    @State private var timeInterval: TimeInterval = 1.0
    @State private var gameRunning = false
    @State private var lastMatchTime: Date? = nil
    @State private var matchMissed: Bool = false
    @State private var showMissTime: Bool = true
    @State private var feedbackDuration: TimeInterval = 0.3
    @State private var timer: Timer?
    @State private var backgroundColor = Color.black
    @State private var level: Int = 1

    /// Run tracking. `taps` counts every tap made while playing and `hits`
    /// only the ones that landed on the target, so accuracy is hits over taps.
    @State private var runStart: Date?
    @State private var taps: Int = 0
    @State private var hits: Int = 0
    @State private var result: RunResult?

    /// Drives the brief "+0.50s" flash on a miss. The token guards against
    /// overlapping taps, where an earlier tap's hide would otherwise clear the
    /// indicator a later one had just raised.
    @State private var showPenalty = false
    @State private var penaltyToken = 0

    struct RunResult {
        let rawTime: TimeInterval
        let penalty: TimeInterval
        let accuracy: Double
        let isNewBest: Bool

        var total: TimeInterval { rawTime + penalty }
    }

    let selectedLevel: Int
    @Binding var gameStarted: Bool

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 30) {
                    VStack {
                        Text("Target Number")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("\(targetNumber)")
                            .font(.system(size: 80))
                            .foregroundColor(.orange)
                    }

                    VStack {
                        Text("Flashing Number")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("\(currentNumber)")
                            .font(.system(size: 100))
                            .foregroundColor(.cyan)
                    }

                    // Always in the layout and only faded, so raising it on a
                    // miss cannot shift the numbers above it mid-game.
                    Text("+\(StatsStore.timeString(StatsStore.wrongTapPenalty))")
                        .font(.title2.bold())
                        .foregroundColor(.red)
                        .opacity(showPenalty ? 1 : 0)
                }

                Spacer()

                HStack {
                    Text("Score: \(score)")
                        .font(.title)
                        .foregroundColor(.white)
                    Spacer()
                    Text("Level: \(level)")
                        .font(.title)
                        .foregroundColor(.white)
                    Spacer()
                    Text("Miss: ")
                        .font(.title)
                        .foregroundColor(.white)
                    Text(missTime != nil ? String(format: "%.2f", missTime!) : "--")
                        .font(.title)
                        .foregroundColor(.white)
                        .opacity(showMissTime ? 1 : 0)
                }
                .padding(.horizontal)

                HStack(spacing: 20) {
                    Button("Stop") {
                        stopGame()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    Button("Back to Menu") {
                        stopGame()
                        gameStarted = false
                    }
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.bottom)
            }

            if let result {
                summary(result)
            }
        }
        .onAppear {
            backgroundColor = .black
            startGame()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onAppear {
            if gameRunning {
                startFlashingNumbers()
            }
        }
        .onTapGesture {
            guard gameRunning else { return }

            let now = Date()
            taps += 1

            // A tap that landed on the target is checked before the pending-miss
            // branch. The other order let a stale "you just missed one" state
            // swallow a tap that was genuinely on the target, which feels unfair
            // and would quietly corrupt the accuracy record.
            if currentNumber == targetNumber {
                hits += 1
                score += 1
                missTime = nil
                lastMatchTime = now
                showMissTime = false
                provideFeedback(isCorrect: true)
                matchMissed = false

                if score >= StatsStore.targetScore {
                    finishRun()
                } else {
                    levelUp()
                }
            } else if matchMissed, let lastTime = lastMatchTime {
                // Still a tap that did not land on the target, so it is charged
                // like any other miss. Acknowledging a missed target and simply
                // tapping at nothing cost the same, which keeps the rule one
                // sentence long: every tap off the target costs time.
                missTime = now.timeIntervalSince(lastTime)
                showMissTime = true
                fadeOutMissTime()
                matchMissed = false
                flashPenalty()
            } else {
                provideFeedback(isCorrect: false)
                flashPenalty()
            }
        }
    }

    @ViewBuilder
    private func summary(_ result: RunResult) -> some View {
        ZStack {
            // Opaque, not a scrim. At 85% the live game bled through and the
            // labels behind collided with the result text on top of them.
            Color.black.ignoresSafeArea()

            VStack(spacing: 18) {
                Text(result.isNewBest ? "New Record!" : "Complete!")
                    .font(.largeTitle.bold())
                    .foregroundColor(result.isNewBest ? .yellow : .white)

                Text(StatsStore.timeString(result.total))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)

                // Spelling the penalty out matters: without it a player who
                // spammed their way to a bad time has no idea why it was bad.
                if result.penalty > 0 {
                    Text("\(StatsStore.timeString(result.rawTime)) + \(StatsStore.timeString(result.penalty)) missed taps")
                        .font(.footnote)
                        .foregroundColor(.red.opacity(0.9))
                }

                Text("\(StatsStore.targetScore) catches · \(StatsStore.percentString(result.accuracy)) accuracy")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))

                if !result.isNewBest, let best = StatsStore.shared.record(for: selectedLevel) {
                    Text("Best \(StatsStore.timeString(best.bestTime))")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.5))
                }

                HStack(spacing: 16) {
                    Button("Play Again") {
                        startGame()
                    }
                    .padding().background(Color.blue).foregroundColor(.white).cornerRadius(10)

                    Button("Menu") {
                        gameStarted = false
                    }
                    .padding().background(Color.gray).foregroundColor(.white).cornerRadius(10)
                }
                .padding(.top, 8)
            }
            .padding(32)
        }
    }

    /// Raises the "+0.50s" indicator for a beat. The token means a later tap's
    /// flash is not cut short by an earlier tap's scheduled hide.
    private func flashPenalty() {
        penaltyToken += 1
        let token = penaltyToken
        withAnimation(.easeOut(duration: 0.1)) { showPenalty = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard token == penaltyToken else { return }
            withAnimation { showPenalty = false }
        }
    }

    func finishRun() {
        gameRunning = false
        timer?.invalidate()
        showPenalty = false

        let elapsed = Date().timeIntervalSince(runStart ?? Date())
        // Every tap that was not a hit is charged, so this covers both a tap at
        // nothing and a late tap acknowledging a target already gone.
        let penalty = Double(max(0, taps - hits)) * StatsStore.wrongTapPenalty
        let accuracy = taps > 0 ? Double(hits) / Double(taps) : 0
        let isNewBest = StatsStore.shared.submit(level: selectedLevel,
                                                 time: elapsed + penalty,
                                                 hits: hits,
                                                 taps: taps)
        result = RunResult(rawTime: elapsed,
                           penalty: penalty,
                           accuracy: accuracy,
                           isNewBest: isNewBest)

        // A finished run is the natural ad break. Pacing still applies, so this
        // stays at one interstitial per 90s however quick the runs get.
        AdManager.shared.noteRoundCompleted()
        AdManager.shared.presentIfAllowed()
    }

    func startGame() {
        score = 0
        level = 1
        targetNumber = Int.random(in: 1...10)
        gameRunning = true
        missTime = nil
        matchMissed = false

        runStart = Date()
        taps = 0
        hits = 0
        showPenalty = false
        result = nil

        switch selectedLevel {
        case 2: timeInterval = 0.5
        case 3: timeInterval = 0.25
        default: timeInterval = 1.0
        }

        startFlashingNumbers()
    }

    /// Abandoning a run part-way. No record is filed — a time is only
    /// comparable if it covers the full set of catches — but it is still a
    /// natural break, so it counts towards ad pacing exactly as before.
    func stopGame() {
        // Stop and Back to Menu are on screen together and both land here, so
        // one game can call this twice. Cleanup is safe to repeat; counting the
        // round is not — it would bill a single game as two towards the next ad.
        let wasRunning = gameRunning

        gameRunning = false
        timer?.invalidate()
        currentNumber = 0

        guard wasRunning else { return }
        AdManager.shared.noteRoundCompleted()
        AdManager.shared.presentIfAllowed()
    }

    func startFlashingNumbers() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
            if currentNumber == targetNumber {
                matchMissed = true
                lastMatchTime = Date()
            }
            currentNumber = Int.random(in: 1...10)
        }
    }

    func fadeOutMissTime() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                showMissTime = false
            }
        }
    }

    func provideFeedback(isCorrect: Bool) {
        withAnimation {
            backgroundColor = isCorrect ? .green : .red
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackDuration) {
            withAnimation {
                backgroundColor = .black
            }
        }
    }

    func levelUp() {
        targetNumber = Int.random(in: 1...10)
        if level < 10 {
            timeInterval = max(0.1, timeInterval * 0.9)
            level += 1
        }
        startFlashingNumbers()
    }
}
