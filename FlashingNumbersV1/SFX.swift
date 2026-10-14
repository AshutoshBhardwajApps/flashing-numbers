import AVFoundation

/// Synthesises short sound effects at runtime — no audio files needed.
/// Ported from CoopHockey; the voices are retuned for catches and misses.
final class SFX {
    static let shared = SFX()

    private let engine = AVAudioEngine()
    private var pool:   [AVAudioPlayerNode] = []
    private var cursor = 0
    private let poolSize = 6

    private static let sampleRate: Double = 44100
    private static let format = AVAudioFormat(
        standardFormatWithSampleRate: sampleRate, channels: 1)!

    private init() {
        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: Self.format)
            pool.append(node)
        }
        try? engine.start()
        pool.forEach { $0.play() }
    }

    // MARK: - Public API

    /// Tap landed on the target: a short bright "tick".
    func playCatch() {
        guard SettingsStore.shared.effectsEnabled else { return }
        let buffer = makeBuffer(
            duration:   0.12,
            decayTime:  0.035,
            freqHz:     880,
            volume:     0.45,
            noiseRatio: 0.08,
            freqSweep:  1.3
        )
        schedule(buffer)
    }

    /// Tap off the target: a low, dull "thud" that reads as a mistake.
    func playMiss() {
        guard SettingsStore.shared.effectsEnabled else { return }
        let buffer = makeBuffer(
            duration:   0.16,
            decayTime:  0.045,
            freqHz:     160,
            volume:     0.40,
            noiseRatio: 0.45,
            freqSweep:  0.6
        )
        schedule(buffer)
    }

    /// Run finished: a longer rising tone.
    func playComplete() {
        guard SettingsStore.shared.effectsEnabled else { return }
        let buffer = makeBuffer(
            duration:   0.45,
            decayTime:  0.14,
            freqHz:     440,
            volume:     0.55,
            noiseRatio: 0.06,
            freqSweep:  2.0
        )
        schedule(buffer)
    }

    // MARK: - Private

    private func schedule(_ buffer: AVAudioPCMBuffer) {
        let node = pool[cursor]
        cursor = (cursor + 1) % poolSize
        node.scheduleBuffer(buffer, completionHandler: nil)
    }

    /// Synthesises a short percussive tone: exponentially-decayed mix of a
    /// sine wave and white noise, with optional frequency sweep.
    private func makeBuffer(duration: Double,
                            decayTime: Double,
                            freqHz: Double,
                            volume: Float,
                            noiseRatio: Float,
                            freqSweep: Double = 1.0) -> AVAudioPCMBuffer {
        let sr    = Self.sampleRate
        let count = AVAudioFrameCount(sr * duration)
        let buf   = AVAudioPCMBuffer(pcmFormat: Self.format, frameCapacity: count)!
        buf.frameLength = count
        let data = buf.floatChannelData![0]

        for i in 0..<Int(count) {
            let t    = Double(i) / sr
            let env  = Float(exp(-t / decayTime))
            let freq = freqHz * pow(freqSweep, t / duration)
            let sine = Float(sin(2 * Double.pi * freq * t))
            let noise = Float.random(in: -1...1)
            data[i] = env * volume * (noiseRatio * noise + (1 - noiseRatio) * sine)
        }
        return buf
    }
}
