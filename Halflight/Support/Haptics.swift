import UIKit

@MainActor
enum Haptics {
    private static let shutterGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let tickGenerator = UISelectionFeedbackGenerator()
    private static let notifyGenerator = UINotificationFeedbackGenerator()

    static func prepare() {
        shutterGenerator.prepare()
    }

    static func shutter(enabled: Bool) {
        guard enabled else { return }
        shutterGenerator.impactOccurred(intensity: 1.0)
    }

    static func tick(enabled: Bool) {
        guard enabled else { return }
        tickGenerator.selectionChanged()
    }

    static func success(enabled: Bool) {
        guard enabled else { return }
        notifyGenerator.notificationOccurred(.success)
    }

    static func warning(enabled: Bool) {
        guard enabled else { return }
        notifyGenerator.notificationOccurred(.warning)
    }
}
