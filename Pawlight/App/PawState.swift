import SwiftUI

/// Root object graph. Simple MV: @Observable models, views read them from the environment.
@MainActor @Observable
final class PawState {
    enum Tab: String, CaseIterable, Identifiable, Hashable {
        case camera, roll, settings

        var id: String { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .camera: "Camera"
            case .roll: "Roll"
            case .settings: "Settings"
            }
        }

        var symbol: String {
            switch self {
            case .camera: "camera"
            case .roll: "photo.on.rectangle"
            case .settings: "gearshape"
            }
        }
    }

    var tab: Tab = .camera

    let settings: PawSettings
    let hinge: HingeObserver
    let media: MediaStore
    let pro: ProStore
    let camera: PetCameraModel

    init() {
        let settings = PawSettings()
        let hinge = HingeObserver()
        let media = MediaStore()
        let pro = ProStore(settings: settings)
        self.settings = settings
        self.hinge = hinge
        self.media = media
        self.pro = pro
        self.camera = PetCameraModel(hinge: hinge, settings: settings, media: media, pro: pro)
    }
}
