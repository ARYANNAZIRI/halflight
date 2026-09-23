import AVFoundation
import Foundation

/// Renders each `LureSound` as mono Float samples. Pure and deterministic (seeded noise), so it
/// is unit-tested and needs no bundled audio.
enum SoundSynth {
    static let sampleRate: Double = 44_100

    static func render(_ sound: LureSound, sampleRate: Double = SoundSynth.sampleRate) -> [Float] {
        var out: [Float]
        switch sound {
        case .squeak: out = squeak(sampleRate)
        case .kiss: out = kiss(sampleRate)
        case .whistle: out = whistle(sampleRate)
        case .chirp: out = chirp(sampleRate)
        case .crinkle: out = crinkle(sampleRate)
        case .bell: out = bell(sampleRate)
        }
        normalize(&out, peak: 0.9)
        return out
    }

    // MARK: Voices

    /// Two rubber-toy squeaks: a fast upward sweep with a buzzy second harmonic.
    private static func squeak(_ sr: Double) -> [Float] {
        var out = silence(0.42, sr)
        for start in [0.0, 0.2] {
            sweep(into: &out, sr: sr, start: start, duration: 0.14, from: 1_700, to: 2_700, harmonics: [1, 0.45, 0.2])
        }
        return out
    }

    /// Three kissy clicks: very short, bright noise bursts.
    private static func kiss(_ sr: Double) -> [Float] {
        var out = silence(0.36, sr)
        var rng = SeededNoise(seed: 7)
        for start in [0.0, 0.12, 0.24] {
            let begin = Int(start * sr)
            let length = Int(0.012 * sr)
            var previous: Float = 0
            for i in 0..<length where begin + i < out.count {
                let env = Float(1 - Double(i) / Double(length))
                let noise = rng.next()
                // First difference = cheap high-pass, which makes the click "smacky".
                out[begin + i] += (noise - previous) * env
                previous = noise
            }
        }
        return out
    }

    /// A rising "come here" whistle with gentle vibrato.
    private static func whistle(_ sr: Double) -> [Float] {
        let duration = 0.55
        var out = silence(duration, sr)
        var phase = 0.0
        for i in 0..<out.count {
            let t = Double(i) / sr
            let x = t / duration
            let freq = 950 + 950 * x * x + 18 * sin(2 * .pi * 6 * t)
            phase += 2 * .pi * freq / sr
            out[i] = Float(sin(phase) * envelope(x, attack: 0.08, release: 0.2))
        }
        return out
    }

    /// Four quick bird chirps, high and short.
    private static func chirp(_ sr: Double) -> [Float] {
        var out = silence(0.5, sr)
        for index in 0..<4 {
            sweep(into: &out, sr: sr, start: Double(index) * 0.11, duration: 0.06, from: 3_000, to: 4_600, harmonics: [1, 0.15])
        }
        return out
    }

    /// Treat-bag crinkle: sparse, random crackle grains.
    private static func crinkle(_ sr: Double) -> [Float] {
        let duration = 0.7
        var out = silence(duration, sr)
        var rng = SeededNoise(seed: 42)
        let grains = 70
        for _ in 0..<grains {
            let start = Int(Double(rng.unit()) * (duration - 0.01) * sr)
            let length = Int((0.001 + 0.004 * Double(rng.unit())) * sr)
            let gain = 0.3 + 0.7 * rng.unit()
            var previous: Float = 0
            for i in 0..<length where start + i < out.count {
                let noise = rng.next()
                out[start + i] += (noise - previous) * gain * Float(1 - Double(i) / Double(length))
                previous = noise
            }
        }
        return out
    }

    /// A small bell: inharmonic partials with an exponential decay.
    private static func bell(_ sr: Double) -> [Float] {
        let duration = 1.2
        var out = silence(duration, sr)
        let partials: [(ratio: Double, gain: Double, decay: Double)] = [(1, 1, 3.2), (2.76, 0.5, 5), (5.4, 0.25, 8), (8.93, 0.12, 11)]
        let base = 1_320.0
        for i in 0..<out.count {
            let t = Double(i) / sr
            var value = 0.0
            for partial in partials {
                value += partial.gain * sin(2 * .pi * base * partial.ratio * t) * exp(-partial.decay * t)
            }
            let attack = min(1, t / 0.003)
            out[i] = Float(value * attack)
        }
        return out
    }

    // MARK: Building blocks

    private static func silence(_ seconds: Double, _ sr: Double) -> [Float] {
        [Float](repeating: 0, count: max(1, Int(seconds * sr)))
    }

    /// Adds an exponential frequency sweep with the given harmonic gains.
    private static func sweep(into out: inout [Float], sr: Double, start: Double, duration: Double, from: Double, to: Double, harmonics: [Double]) {
        let begin = Int(start * sr)
        let length = Int(duration * sr)
        var phase = 0.0
        for i in 0..<length where begin + i < out.count {
            let x = Double(i) / Double(length)
            let freq = from * pow(to / from, x)
            phase += 2 * .pi * freq / sr
            var value = 0.0
            for (index, gain) in harmonics.enumerated() {
                value += gain * sin(phase * Double(index + 1))
            }
            out[begin + i] += Float(value * envelope(x, attack: 0.1, release: 0.25))
        }
    }

    /// Linear attack, flat middle, linear release, over x in 0...1.
    static func envelope(_ x: Double, attack: Double, release: Double) -> Double {
        if x < attack { return x / attack }
        if x > 1 - release { return max(0, (1 - x) / release) }
        return 1
    }

    static func normalize(_ samples: inout [Float], peak: Float) {
        let maxValue = samples.reduce(Float(0)) { max($0, abs($1)) }
        guard maxValue > 0 else { return }
        let scale = peak / maxValue
        for i in samples.indices { samples[i] *= scale }
    }
}

/// Tiny deterministic noise source (xorshift), so rendered sounds are identical every run.
struct SeededNoise {
    private var state: UInt32

    init(seed: UInt32) { state = seed == 0 ? 1 : seed }

    /// -1...1
    mutating func next() -> Float {
        unit() * 2 - 1
    }

    /// 0...1
    mutating func unit() -> Float {
        state ^= state << 13
        state ^= state >> 17
        state ^= state << 5
        return Float(state) / Float(UInt32.max)
    }
}

/// Plays lure sounds through the speaker, even with the ring switch on silent: a pet can't
/// hear a muted phone. Buffers are rendered once and cached.
@MainActor
final class LureSoundPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat?
    private var buffers: [LureSound: AVAudioPCMBuffer] = [:]
    private var isSetUp = false

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: SoundSynth.sampleRate, channels: 1)
    }

    /// 0...1
    var volume: Float = 1 {
        didSet { player.volume = volume }
    }

    func play(_ sound: LureSound) {
        guard setUpIfNeeded(), let buffer = buffer(for: sound) else { return }
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    func stop() {
        player.stop()
        engine.pause()
    }

    private func setUpIfNeeded() -> Bool {
        if isSetUp { return true }
        guard let format else { return false }
        let audio = AVAudioSession.sharedInstance()
        // .playback ignores the silent switch; mixing leaves the user's music alone.
        try? audio.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? audio.setActive(true)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        player.volume = volume
        isSetUp = true
        return true
    }

    private func buffer(for sound: LureSound) -> AVAudioPCMBuffer? {
        if let cached = buffers[sound] { return cached }
        guard let format else { return nil }
        let samples = SoundSynth.render(sound)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        for i in samples.indices { channel[i] = samples[i] }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        buffers[sound] = buffer
        return buffer
    }
}
