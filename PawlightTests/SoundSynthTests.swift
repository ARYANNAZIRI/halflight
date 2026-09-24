import Foundation
import Testing
@testable import Pawlight

struct SoundSynthTests {
    @Test(arguments: LureSound.allCases)
    func rendersAudibleShortClip(_ sound: LureSound) {
        let samples = SoundSynth.render(sound)
        let seconds = Double(samples.count) / SoundSynth.sampleRate
        #expect(seconds > 0.1)
        #expect(seconds < 1.5)
        let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
        #expect(peak > 0.5)
        #expect(peak <= 0.9001)
        #expect(!samples.contains { $0.isNaN || $0.isInfinite })
    }

    @Test(arguments: LureSound.allCases)
    func isDeterministic(_ sound: LureSound) {
        #expect(SoundSynth.render(sound) == SoundSynth.render(sound))
    }

    @Test func envelopeShape() {
        #expect(SoundSynth.envelope(0, attack: 0.1, release: 0.2) == 0)
        #expect(SoundSynth.envelope(0.5, attack: 0.1, release: 0.2) == 1)
        #expect(SoundSynth.envelope(1, attack: 0.1, release: 0.2) == 0)
    }

    @Test func seededNoiseStaysInRange() {
        var noise = SeededNoise(seed: 3)
        for _ in 0..<10_000 {
            let value = noise.next()
            #expect(value >= -1 && value <= 1)
        }
    }
}
