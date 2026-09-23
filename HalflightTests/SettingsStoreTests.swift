import Foundation
import Testing
@testable import Halflight

@MainActor
struct SettingsStoreTests {
    @Test func persistsAcrossInstances() throws {
        let suite = "halflight-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = SettingsStore(defaults: defaults)
        #expect(first.defaultFacingMode == .mirror)
        #expect(!first.onboardingDone)
        first.defaultFacingMode = .prompt
        first.promptSpeed = 75
        first.onboardingDone = true

        let second = SettingsStore(defaults: defaults)
        #expect(second.defaultFacingMode == .prompt)
        #expect(second.promptSpeed == 75)
        #expect(second.onboardingDone)
    }

    #if DEBUG
    @Test func fakeDuoDrivesPostureAndAvailability() throws {
        let suite = "halflight-hinge-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let hinge = HingeObserver(defaults: defaults)
        #expect(!hinge.isDuo)
        #expect(!hinge.facingAvailable)

        hinge.fake.enabled = true
        hinge.fake.posture = .tent
        #expect(hinge.isDuo)
        #expect(hinge.posture == .tent)
        #expect(hinge.facingAvailable)

        hinge.fake.posture = .closed
        #expect(!hinge.facingAvailable)

        // Real hinge reports are ignored while faking.
        hinge.reportHinge(angle: 180)
        #expect(hinge.posture == .closed)

        hinge.fake.enabled = false
        hinge.reportHinge(angle: 100)
        #expect(hinge.posture == .tent)
        #expect(hinge.isDuo)
    }
    #endif
}
