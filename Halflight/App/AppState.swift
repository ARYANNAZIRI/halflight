import SwiftUI

/// Root object graph. Simple MV: @Observable models, views read them from the environment.
@MainActor @Observable
final class AppState {
    enum Tab: String, CaseIterable, Identifiable, Hashable {
        case capture, facing, roll, edit, settings

        var id: String { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .capture: "Capture"
            case .facing: "Facing"
            case .roll: "Roll"
            case .edit: "Edit"
            case .settings: "Settings"
            }
        }

        var symbol: String {
            switch self {
            case .capture: "camera"
            case .facing: "rectangle.on.rectangle.angled"
            case .roll: "photo.on.rectangle"
            case .edit: "slider.horizontal.3"
            case .settings: "gearshape"
            }
        }
    }

    var tab: Tab = .capture
    var editingItemID: MediaItem.ID?

    let settings: SettingsStore
    let hinge: HingeObserver
    let media: MediaStore
    let prompts: PromptStore
    let capture: CaptureModel

    init() {
        let settings = SettingsStore()
        let hinge = HingeObserver()
        let media = MediaStore()
        let prompts = PromptStore()
        self.settings = settings
        self.hinge = hinge
        self.media = media
        self.prompts = prompts
        self.capture = CaptureModel(hinge: hinge, settings: settings, media: media, prompts: prompts)
    }

    func openInEditor(_ item: MediaItem) {
        editingItemID = item.id
        tab = .edit
    }
}
