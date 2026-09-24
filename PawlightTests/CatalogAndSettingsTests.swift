import Foundation
import Testing
@testable import Pawlight

struct CatalogTests {
    @Test func twoFreeLuresAndTwoFreeSounds() {
        #expect(Lure.allCases.filter(\.isFree) == [.zipDot, .bouncyBall])
        #expect(LureSound.allCases.filter(\.isFree) == [.squeak, .kiss])
    }

    @Test func loopsAreShortAndPositive() {
        for lure in Lure.allCases {
            #expect(lure.loopDuration >= 3 && lure.loopDuration <= 12)
        }
    }

    @Test func nextCyclesThroughEveryLure() {
        var seen: Set<Lure> = []
        var lure = Lure.zipDot
        for _ in Lure.allCases {
            seen.insert(lure)
            lure = lure.next
        }
        #expect(seen.count == Lure.allCases.count)
        #expect(lure == .zipDot)
    }
}

@MainActor
struct PawSettingsTests {
    private func freshDefaults() -> UserDefaults {
        let name = "pawlight.tests.\(UUID().uuidString)"
        return UserDefaults(suiteName: name) ?? .standard
    }

    @Test func persistsAcrossInstances() {
        let defaults = freshDefaults()
        let first = PawSettings(defaults: defaults)
        first.catchOn = false
        first.lure = .feather
        first.sound = .bell
        let second = PawSettings(defaults: defaults)
        #expect(second.catchOn == false)
        #expect(second.lure == .feather)
        #expect(second.sound == .bell)
    }

    @Test func clampsShotsAndVolume() {
        let settings = PawSettings(defaults: freshDefaults())
        settings.shotsPerCatch = 12
        #expect(settings.shotsPerCatch == 5)
        settings.shotsPerCatch = 0
        #expect(settings.shotsPerCatch == 1)
        settings.soundVolume = 3
        #expect(settings.soundVolume == 1)
    }

    @Test func freeUserGetsOneShotPerCatch() {
        let settings = PawSettings(defaults: freshDefaults())
        settings.shotsPerCatch = 5
        let pro = ProStore(settings: settings)
        #expect(!pro.isPro)
        #expect(pro.isUnlocked(Lure.zipDot))
        #expect(!pro.isUnlocked(Lure.feather))
        #expect(!pro.isUnlocked(LureSound.bell))
    }
}
