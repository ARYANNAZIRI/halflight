import Foundation

/// User settings, persisted as one Codable blob in UserDefaults. Never stores media.
@MainActor @Observable
final class SettingsStore {
    struct Values: Codable, Equatable, Sendable {
        var defaultLens: CameraSession.Lens = .main
        var defaultFacingMode: FacingMode = .mirror
        var gridOn = false
        var saveOriginalAndEdit = true
        var hapticsOn = true
        var cueSoundOn = false
        var cueAutoCapture = true
        var autoCapture = false
        var promptSpeed: Double = 40
        var promptFontSize: Double = 44
        var promptMirrored = false
        var onboardingDone = false
    }

    private static let key = "halflight.settings"
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
        if let data = try? JSONEncoder().encode(values) {
            defaults.set(data, forKey: Self.key)
        }
    }

    func resetOnboarding() {
        values.onboardingDone = false
    }

    // Passthroughs keep call sites short and bindable.
    var defaultLens: CameraSession.Lens { get { values.defaultLens } set { values.defaultLens = newValue } }
    var defaultFacingMode: FacingMode { get { values.defaultFacingMode } set { values.defaultFacingMode = newValue } }
    var gridOn: Bool { get { values.gridOn } set { values.gridOn = newValue } }
    var saveOriginalAndEdit: Bool { get { values.saveOriginalAndEdit } set { values.saveOriginalAndEdit = newValue } }
    var hapticsOn: Bool { get { values.hapticsOn } set { values.hapticsOn = newValue } }
    var cueSoundOn: Bool { get { values.cueSoundOn } set { values.cueSoundOn = newValue } }
    var cueAutoCapture: Bool { get { values.cueAutoCapture } set { values.cueAutoCapture = newValue } }
    var autoCapture: Bool { get { values.autoCapture } set { values.autoCapture = newValue } }
    var promptSpeed: Double { get { values.promptSpeed } set { values.promptSpeed = newValue } }
    var promptFontSize: Double { get { values.promptFontSize } set { values.promptFontSize = newValue } }
    var promptMirrored: Bool { get { values.promptMirrored } set { values.promptMirrored = newValue } }
    var onboardingDone: Bool { get { values.onboardingDone } set { values.onboardingDone = newValue } }
}
