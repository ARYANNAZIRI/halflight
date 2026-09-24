import SwiftUI
import UIKit

/// Main-actor state for the pet camera. Talks to Halflight's `CameraSession` actor and never
/// touches AVFoundation directly.
@MainActor @Observable
final class PetCameraModel {
    enum Status: Equatable {
        case idle, starting, running, unauthorized
        case interrupted(String)
        case failed(String)
    }

    let session = CameraSession()
    let hinge: HingeObserver
    let settings: PawSettings
    let media: MediaStore
    let pro: ProStore
    let sounds = LureSoundPlayer()

    // MARK: Camera state

    var status: Status = .idle
    var capabilities = CameraSession.Capabilities()
    var previewSource: CameraSession.PreviewSource?
    var lens: CameraSession.Lens = .main
    var zoom: CGFloat = 1
    var isCapturing = false
    var lastShot: MediaItem?
    var toast: String?
    var alert: AlertItem?
    var showPaywall = false
    private(set) var sessionID = UUID()

    // MARK: Pet state

    var look: PetLook = .none
    var species: PetSample.Species?
    /// Outer display shows the lure. Bound to the Duo scene accessory.
    var lureOn = false
    /// A sound was just played: catch the next look even when Catch is off.
    private(set) var callArmedUntil: Date?
    /// Shots taken by Catch this session, shown as a small counter.
    private(set) var catches = 0

    #if DEBUG
    /// Screenshot mode (Settings → Developer): a chosen photo stands in for the viewfinder and
    /// the badge shows "Looking!", because the simulator has no camera.
    var demoImage: UIImage?
    #endif

    @ObservationIgnored private var evaluator = PetLookEvaluator()
    @ObservationIgnored private var lastCatch: Date?
    @ObservationIgnored private var lastActivity = Date.now
    @ObservationIgnored private var releaseTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var eventTask: Task<Void, Never>?

    init(hinge: HingeObserver, settings: PawSettings, media: MediaStore, pro: ProStore) {
        self.hinge = hinge
        self.settings = settings
        self.media = media
        self.pro = pro
        sounds.volume = Float(settings.soundVolume)
        startEventLoop()
    }

    // MARK: Derived

    var isRunning: Bool { status == .running }
    var isDuo: Bool { hinge.isDuo }
    var lureAvailable: Bool { hinge.facingAvailable && lens != .front }
    var lureIsLive: Bool { lureOn && lureAvailable }
    var lure: Lure { settings.lure }

    var isDemo: Bool {
        #if DEBUG
        return demoImage != nil
        #else
        return false
        #endif
    }

    /// What the UI shows: the real look, or "Looking!" in screenshot mode.
    var shownLook: PetLook { isDemo ? .looking : look }

    /// Pro takes a burst per catch; free takes one shot.
    var shotsPerCatch: Int { pro.isPro ? settings.shotsPerCatch : 1 }

    var catchArmed: Bool {
        if settings.catchOn { return true }
        if let until = callArmedUntil, until > .now { return true }
        return false
    }

    // MARK: Lifecycle

    func start() async {
        releaseTask?.cancel()
        releaseTask = nil
        switch status {
        case .running, .starting: return
        default: break
        }
        status = .starting
        guard await Permissions.camera() else {
            status = .unauthorized
            return
        }
        do {
            try await session.configure(lens: lens, mode: .photo)
            capabilities = await session.capabilities
            previewSource = await session.previewSource()
            zoom = await session.displayZoom()
            await session.start()
            status = .running
            if Date.now.timeIntervalSince(lastActivity) > 30 * 60 { sessionID = UUID() }
            lastActivity = .now
            await installAnalyzer()
            Haptics.prepare()
            EventLog.log("pet_capture_start", ["lens": lens.rawValue])
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func retry() {
        status = .idle
        Task { [self] in await start() }
    }

    /// Leaving the camera: release it after a short grace period so tab hops stay instant.
    func scheduleRelease(after seconds: Double = 3) {
        releaseTask?.cancel()
        releaseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            await self.stop()
        }
    }

    func stop() async {
        await session.setFrameAnalyzer(nil)
        await session.stop()
        sounds.stop()
        look = .none
        species = nil
        evaluator.reset()
        if case .unauthorized = status { return }
        status = .idle
    }

    func postureChanged(_ posture: DevicePosture) {
        if posture == .closed { lureOn = false }
    }

    private func startEventLoop() {
        let session = self.session
        eventTask = Task { @MainActor [weak self] in
            for await event in session.events {
                guard let self else { return }
                self.handle(event)
            }
        }
    }

    private func handle(_ event: CameraSession.Event) {
        switch event {
        case .interrupted(let reason):
            status = .interrupted(reason)
        case .interruptionEnded:
            if case .interrupted = status { status = .running }
        case .runtimeError(let message):
            status = .failed(message)
        case .recordingStarted, .recordingFinished, .recordingFailed:
            // Pawlight is photo-only; the session never records.
            break
        }
    }

    // MARK: Lens and zoom

    func flipCamera() {
        let next: CameraSession.Lens = lens == .front ? .main : .front
        if next == .front, !capabilities.hasFront { return }
        lens = next
        if next == .front { lureOn = false }
        Task { [self] in
            do {
                zoom = try await session.setLens(next)
                capabilities = await session.capabilities
                previewSource = await session.previewSource()
                await installAnalyzer()
            } catch {
                alert = AlertItem(title: String(localized: "Couldn’t switch camera"), message: error.localizedDescription)
            }
        }
    }

    /// Duo: the preview view reports which cameras face the subject as the phone flips.
    func directionsChanged(_ directions: CameraDirections) {
        Task { [self] in
            if (try? await session.applyDirections(directions)) == true {
                previewSource = await session.previewSource()
                capabilities = await session.capabilities
                await installAnalyzer()
            }
        }
    }

    func setZoom(_ display: CGFloat) {
        Task { [self] in
            zoom = await session.setZoom(display: display)
        }
    }

    func focus(devicePoint: CGPoint) {
        Task { [self] in await session.focus(at: devicePoint) }
    }

    // MARK: Lures and sounds

    func selectLure(_ lure: Lure) {
        guard pro.isUnlocked(lure) else {
            showPaywall = true
            return
        }
        settings.lure = lure
        EventLog.log("lure_selected", ["lure": lure.rawValue])
    }

    func toggleLure() {
        guard lureAvailable else {
            lureOn = false
            return
        }
        lureOn.toggle()
        evaluator.reset()
    }

    /// Plays a sound and arms a one-off catch for the next 3 seconds.
    func call(_ sound: LureSound) {
        guard pro.isUnlocked(sound) else {
            showPaywall = true
            return
        }
        settings.sound = sound
        sounds.volume = Float(settings.soundVolume)
        sounds.play(sound)
        callArmedUntil = Date.now.addingTimeInterval(3)
        evaluator.reset()
        EventLog.log("sound_played", ["sound": sound.rawValue])
    }

    // MARK: Shutter

    func shutterTapped() {
        guard case .running = status else { return }
        lastActivity = .now
        Task { [self] in await capture(shots: shotsPerCatch) }
    }

    func capture(shots: Int) async {
        guard case .running = status, !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }
        Haptics.shutter(enabled: settings.hapticsOn)
        do {
            for _ in 0..<max(1, shots) {
                let photo = try await session.capturePhoto(flash: .off)
                let item = try await media.addPhoto(data: photo.data, sessionID: sessionID)
                lastShot = item
            }
            showToast(shots > 1 ? String(localized: "\(shots) shots saved") : String(localized: "Saved to Roll"))
            EventLog.log("pet_photo_saved", ["shots": "\(shots)"])
        } catch {
            alert = AlertItem(title: String(localized: "Couldn’t take the photo"), message: error.localizedDescription)
        }
    }

    // MARK: Catch (auto-capture on look)

    private func installAnalyzer() async {
        guard status == .running else {
            await session.setFrameAnalyzer(nil)
            return
        }
        evaluator.reset()
        let analyzer = PetFrameAnalyzer { [weak self] sample in
            Task { @MainActor in self?.ingest(sample) }
        }
        await session.setFrameAnalyzer(analyzer)
    }

    func ingest(_ sample: PetSample) {
        guard case .running = status else { return }
        let next = evaluator.ingest(sample)
        if let first = sample.species.first { species = first } else if next == .none { species = nil }
        if next != look {
            look = next
            if next == .looking { Haptics.tick(enabled: settings.hapticsOn) }
        }
        if next == .looking { maybeCatch() }
    }

    /// Never while busy, and never twice within 2.5s, so a pet that keeps looking doesn't fill
    /// the roll with near-duplicates.
    private func maybeCatch() {
        guard catchArmed, !isCapturing else { return }
        if let last = lastCatch, Date.now.timeIntervalSince(last) < 2.5 { return }
        lastCatch = .now
        callArmedUntil = nil
        catches += 1
        EventLog.log("pet_catch")
        Task { [self] in await capture(shots: shotsPerCatch) }
    }

    // MARK: Toast

    func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}
