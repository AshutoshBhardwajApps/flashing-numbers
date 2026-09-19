// Entry point with screen switching
import SwiftUI

struct ContentView: View {
    @State private var showWelcomeView = true
    @State private var gameStarted = false
    @State private var selectedLevel = 1

    var body: some View {
        if showWelcomeView {
            WelcomeView(showWelcomeView: $showWelcomeView)
        } else if gameStarted {
            GameView(selectedLevel: selectedLevel, gameStarted: $gameStarted)
        } else {
            IntroScreen(gameStarted: $gameStarted, selectedLevel: $selectedLevel)
        }
    }
}

struct IntroScreen: View {
    @Binding var gameStarted: Bool
    @Binding var selectedLevel: Int

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

            if matchMissed, let lastTime = lastMatchTime {
                missTime = now.timeIntervalSince(lastTime)
                showMissTime = true
                fadeOutMissTime()
                matchMissed = false
            } else if currentNumber == targetNumber {
                score += 1
                missTime = nil
                lastMatchTime = now
                showMissTime = false
                provideFeedback(isCorrect: true)
                matchMissed = false
                levelUp()
            } else {
                provideFeedback(isCorrect: false)
            }
        }
    }

    func startGame() {
        score = 0
        level = 1
        targetNumber = Int.random(in: 1...10)
        gameRunning = true
        missTime = nil
        matchMissed = false

        switch selectedLevel {
        case 2: timeInterval = 0.5
        case 3: timeInterval = 0.25
        default: timeInterval = 1.0
        }

        startFlashingNumbers()
    }

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
