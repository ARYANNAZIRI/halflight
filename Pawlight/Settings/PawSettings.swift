import Foundation

/// User settings, persisted as one Codable blob in UserDefaults. Never stores media.
@MainActor @Observable
final class PawSettings {
    struct Values: Codable, Equatable, Sendable {
        /// Take the shot automatically the moment the pet looks at the lens.
        var catchOn = true
        /// Shots per catch or shutter press. More than 1 needs Pro.
        var shotsPerCatch = 3
        var lure: Lure = .zipDot
        var sound: LureSound = .squeak
        var soundVolume: Double = 1
        var hapticsOn = true
        #if DEBUG
        var pretendPro = false
        #endif
    }

    private static let key = "pawlight.settings"
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var storage: Values

    /// Manual observation accessors so the write-through persist runs on every mutation.
    var values: Values {
        get {
            access(keyPath: \.values)
            return storage
        }
        set {
            withMutation(keyPath: \.values) {
                storage = newValue
                persist()
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(Values.self, from: data) {
            storage = decoded
        } else {
            storage = Values()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(storage) {
            defaults.set(data, forKey: Self.key)
        }
    }

    var catchOn: Bool { get { values.catchOn } set { values.catchOn = newValue } }
    var shotsPerCatch: Int { get { values.shotsPerCatch } set { values.shotsPerCatch = min(5, max(1, newValue)) } }
    var lure: Lure { get { values.lure } set { values.lure = newValue } }
    var sound: LureSound { get { values.sound } set { values.sound = newValue } }
    var soundVolume: Double { get { values.soundVolume } set { values.soundVolume = min(1, max(0, newValue)) } }
    var hapticsOn: Bool { get { values.hapticsOn } set { values.hapticsOn = newValue } }
}
