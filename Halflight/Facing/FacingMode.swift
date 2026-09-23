import SwiftUI

/// What the person in front of the phone sees on the outer display.
enum FacingMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case mirror, motionCue, prompt, count, off

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .mirror: "Mirror"
        case .motionCue: "Motion Cue"
        case .prompt: "Prompt"
        case .count: "Count"
        case .off: "Off"
        }
    }

    /// Pictogram, not a label.
    var symbol: String {
        switch self {
        case .mirror: "person.crop.rectangle"
        case .motionCue: "circle.hexagonpath"
        case .prompt: "text.alignleft"
        case .count: "timer"
        case .off: "rectangle.slash"
        }
    }

    var summary: LocalizedStringKey {
        switch self {
        case .mirror: "They see themselves before you shoot."
        case .motionCue: "Big, quiet motion that pulls a child’s eyes to the camera."
        case .prompt: "A script scrolls on the outer screen while you film."
        case .count: "A large countdown, then the shot they just took."
        case .off: "The outer screen stays dark."
        }
    }

    /// Modes the onboarding offers as a default.
    static let onboardingChoices: [FacingMode] = [.mirror, .motionCue, .prompt]
}
