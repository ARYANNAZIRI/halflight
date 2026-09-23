import SwiftUI
import UIKit

/// Main-actor state for Capture and Facing. Talks to `CameraSession` (an actor) and never
/// touches AVFoundation directly.
@MainActor @Observable
final class CaptureModel {
    enum Status: Equatable {
        case idle, starting, running, unauthorized
        case interrupted(String)
        case failed(String)
    }

    enum TimerOption: Int, CaseIterable, Identifiable {
        case off = 0, three = 3, ten = 10
        var id: Int { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .off: "Off"
            case .three: "3s"
            case .ten: "10s"
            }
        }
    }

    enum HintState: Equatable { case off, searching, ready }

    let session = CameraSession()
    let hinge: HingeObserver
    let settings: SettingsStore
    let media: MediaStore
    let prompts: PromptStore

    // MARK: Camera state

    var status: Status = .idle
    var capabilities = CameraSession.Capabilities()
    var previewSource: CameraSession.PreviewSource?
    var lens: CameraSession.Lens
    var mode: CameraSession.CaptureMode = .photo
    var flash: CameraSession.FlashMode = .off
    var torchOn = false
    var gridOn: Bool
    var levelOn = false
    var exposureBias: Double = 0
    /// Display zoom: 1 = main, `capabilities.ultraWideZoom` = ultra wide.
    var zoom: CGFloat = 1
    var timer: TimerOption = .off
    var burstOn = false
    var countdown: Int?
    var isCapturing = false
    var isRecording = false
    var recordingStart: Date?
    var lastShot: MediaItem?
    var freezeFrame: UIImage?
    var focusPoint: CGPoint?
    var toast: String?
    var alert: AlertItem?
    private(set) var sessionID = UUID()

    // MARK: Facing state

    var facingEnabled = false
    var facingMode: FacingMode
    var cue: MotionCue = .emberOrb
    var mixCues = false
    var cueStartedAt: Date?
    var showPoseSilhouette = false
    var mirrorCountdown = true
    /// Non-Duo phones: play the cue full-screen on the same display.
    var cueOverlayShown = false

    // MARK: Prompt state

    var promptScriptID: UUID?
    var promptPlaying = false
    var promptAnchor: Date?
    var promptPausedElapsed: TimeInterval = 0
    /// Points per second.
    var promptSpeed: Double
    var promptFontSize: Double
    var promptMirrored: Bool

    // MARK: Still Hint

    var hint: HintState = .off
    var autoCapture: Bool
    var autoCaptureWarning: Int?

    @ObservationIgnored private var evaluator = StillHintEvaluator()
    @ObservationIgnored private var lastAutoCapture: Date?
    @ObservationIgnored private var lastActivity = Date.now
    @ObservationIgnored private var autoCaptureTask: Task<Void, Never>?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var releaseTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var freezeTask: Task<Void, Never>?
    @ObservationIgnored private var focusTask: Task<Void, Never>?
    @ObservationIgnored private var mixTask: Task<Void, Never>?
    @ObservationIgnored private var eventTask: Task<Void, Never>?

    init(hinge: HingeObserver, settings: SettingsStore, media: MediaStore, prompts: PromptStore) {
        self.hinge = hinge
        self.settings = settings
        self.media = media
        self.prompts = prompts
        lens = settings.defaultLens
        gridOn = settings.gridOn
        facingMode = settings.defaultFacingMode
        promptSpeed = settings.promptSpeed
        promptFontSize = settings.promptFontSize
        promptMirrored = settings.promptMirrored
        autoCapture = settings.autoCapture
        promptScriptID = prompts.scripts.first?.id
        startEventLoop()
    }

    // MARK: Derived

    var isRunning: Bool { status == .running }
    var handsFree: Bool { hinge.posture == .tent }
    var facingAvailable: Bool { hinge.facingAvailable }
    var isDuo: Bool { hinge.isDuo }
    var promptScript: PromptScript? { prompts.script(id: promptScriptID) }
    var facingIsLive: Bool { facingEnabled && facingAvailable && facingMode != .off }

    /// Seconds the current cue has been on screen.
    func cueAge(at date: Date = .now) -> TimeInterval {
        cueStartedAt.map { date.timeIntervalSince($0) } ?? 0
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
            try await session.configure(lens: lens, mode: mode)
            capabilities = await session.capabilities
            previewSource = await session.previewSource()
            zoom = await session.displayZoom()
            await session.start()
            status = .running
            refreshSessionID()
            await updateHintTap()
            Haptics.prepare()
            EventLog.log("capture_start", ["lens": lens.rawValue, "mode": mode.rawValue])
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func retry() {
        status = .idle
        Task { [self] in await start() }
    }

    /// Leaving Capture: release the camera after a short grace period so tab hops stay instant.
    func scheduleRelease(after seconds: Double = 3) {
        releaseTask?.cancel()
        releaseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            await self.stop()
        }
    }

    func stop() async {
        cancelCountdown()
        cancelAutoCapture()
        await session.stop()
        hint = .off
        if case .unauthorized = status { return }
        status = .idle
        EventLog.log("capture_stop")
    }

    /// Backgrounding: stop recording cleanly (the file is stored from the finish event).
    func enterBackground() async {
        cancelCountdown()
        cancelAutoCapture()
        if isRecording { await session.stopRecording() }
    }

    func postureChanged(_ posture: DevicePosture) {
        if posture == .closed {
            facingEnabled = false
            cancelCountdown()
        }
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
            cancelCountdown()
            cancelAutoCapture()
        case .interruptionEnded:
            if case .interrupted = status { status = .running }
        case .runtimeError(let message):
            status = .failed(message)
        case .recordingStarted:
            isRecording = true
            recordingStart = .now
        case .recordingFinished(let url):
            isRecording = false
            recordingStart = nil
            Task { [self] in await storeVideo(at: url) }
        case .recordingFailed(let message):
            isRecording = false
            recordingStart = nil
            alert = AlertItem(title: String(localized: "Recording stopped"), message: message)
        }
    }

    private func refreshSessionID() {
        if Date.now.timeIntervalSince(lastActivity) > 30 * 60 { sessionID = UUID() }
        lastActivity = .now
    }

    // MARK: Mode, lens, zoom, focus

    func setMode(_ new: CameraSession.CaptureMode) {
        guard new != mode, !isRecording else { return }
        mode = new
        cancelCountdown()
        cancelAutoCapture()
        Task { [self] in
            if new == .video { _ = await Permissions.microphone() }
            await session.setMode(new)
            capabilities = await session.capabilities
            await updateHintTap()
        }
    }

    func setLens(_ new: CameraSession.Lens) {
        guard new != lens, !isRecording else { return }
        if new == .ultraWide, !capabilities.hasUltraWide { return }
        if new == .front, !capabilities.hasFront { return }
        lens = new
        Task { [self] in
            do {
                zoom = try await session.setLens(new)
                capabilities = await session.capabilities
                previewSource = await session.previewSource()
                await updateHintTap()
            } catch {
                alert = AlertItem(title: String(localized: "Couldn’t switch camera"), message: error.localizedDescription)
            }
        }
    }

    func flipCamera() {
        setLens(lens == .front ? .main : .front)
    }

    /// Duo: the preview view reports which cameras face the subject as the phone flips.
    func directionsChanged(_ directions: CameraDirections) {
        Task { [self] in
            if (try? await session.applyDirections(directions)) == true {
                previewSource = await session.previewSource()
                capabilities = await session.capabilities
                await updateHintTap()
            }
        }
    }

    func setZoom(_ display: CGFloat) {
        Task { [self] in
            let applied = await session.setZoom(display: display)
            zoom = applied
            if lens != .front {
                let ultra = capabilities.hasUltraWide && applied < 0.999
                let next: CameraSession.Lens = ultra ? .ultraWide : .main
                if next != lens { lens = next }
            }
        }
    }

    func focus(viewPoint: CGPoint, devicePoint: CGPoint) {
        focusPoint = viewPoint
        Task { [self] in await session.focus(at: devicePoint) }
        focusTask?.cancel()
        focusTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            self?.focusPoint = nil
        }
    }

    func setExposureBias(_ value: Double) {
        exposureBias = value
        Task { [self] in await session.setExposureBias(Float(value)) }
    }

    func setTorch(_ on: Bool) {
        torchOn = on
        Task { [self] in await session.setTorch(on) }
    }

    func cycleFlash() {
        let all = CameraSession.FlashMode.allCases
        guard let index = all.firstIndex(of: flash) else { return }
        flash = all[(index + 1) % all.count]
    }

    func cycleTimer() {
        let all = TimerOption.allCases
        guard let index = all.firstIndex(of: timer) else { return }
        timer = all[(index + 1) % all.count]
    }

    // MARK: Shutter

    func shutterTapped() {
        guard case .running = status else { return }
        lastActivity = .now
        if mode == .video {
            Task { [self] in
                if isRecording {
                    await session.stopRecording()
                } else {
                    await startRecording()
                }
            }
            return
        }
        if countdown != nil {
            cancelCountdown()
            return
        }
        let seconds = (timer == .off && handsFree) ? TimerOption.three.rawValue : timer.rawValue
        if seconds > 0 {
            runCountdown(seconds)
        } else {
            Task { [self] in await capturePhoto() }
        }
    }

    func runCountdown(_ seconds: Int) {
        countdownTask?.cancel()
        cancelAutoCapture()
        countdown = seconds
        countdownTask = Task { [weak self] in
            var remaining = seconds
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                remaining -= 1
                guard let self else { return }
                self.countdown = remaining
                Haptics.tick(enabled: self.settings.hapticsOn)
            }
            guard let self else { return }
            self.countdown = nil
            await self.capturePhoto()
        }
    }

    func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdown = nil
    }

    func capturePhoto() async {
        guard case .running = status, !isCapturing, mode == .photo else { return }
        isCapturing = true
        defer { isCapturing = false }
        Haptics.shutter(enabled: settings.hapticsOn)
        let shots = burstOn ? 5 : 1
        do {
            for _ in 0..<shots {
                let photo = try await session.capturePhoto(flash: flash)
                let item = try await media.addPhoto(data: photo.data, sessionID: sessionID)
                lastShot = item
                EventLog.log("photo_saved", ["id": item.id.uuidString])
            }
            showToast(String(localized: "Saved to Roll"))
            if facingIsLive, facingMode == .count, let item = lastShot {
                await showFreezeFrame(for: item)
            }
            evaluator.reset()
            if hint == .ready { hint = .searching }
        } catch {
            alert = AlertItem(title: String(localized: "Couldn’t take the photo"), message: error.localizedDescription)
        }
    }

    private func showFreezeFrame(for item: MediaItem) async {
        freezeTask?.cancel()
        freezeFrame = await media.thumbnail(for: item)
        freezeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.freezeFrame = nil
        }
    }

    // MARK: Video

    private func startRecording() async {
        guard StorageMonitor.hasRoom(minimumMB: 300) else {
            alert = AlertItem(
                title: String(localized: "Not enough space"),
                message: String(localized: "Free up some storage before recording video.")
            )
            return
        }
        let url = media.newVideoURL()
        do {
            try await session.startRecording(to: url)
            Haptics.shutter(enabled: settings.hapticsOn)
            EventLog.log("video_start")
        } catch {
            alert = AlertItem(title: String(localized: "Couldn’t start recording"), message: error.localizedDescription)
        }
    }

    private func storeVideo(at url: URL) async {
        let task = UIApplication.shared.beginBackgroundTask(withName: "app.halflight.saveVideo")
        defer { if task != .invalid { UIApplication.shared.endBackgroundTask(task) } }
        do {
            let item = try await media.addVideo(at: url, sessionID: sessionID)
            lastShot = item
            showToast(String(localized: "Saved to Roll"))
            EventLog.log("video_saved", ["id": item.id.uuidString])
        } catch {
            alert = AlertItem(title: String(localized: "Couldn’t save the video"), message: error.localizedDescription)
        }
    }

    // MARK: Facing

    /// Call from `.onChange(of: model.facingEnabled)`.
    func facingChanged() {
        if facingEnabled, !facingAvailable {
            facingEnabled = false
            return
        }
        EventLog.log("facing_toggled", ["on": facingEnabled ? "1" : "0", "mode": facingMode.rawValue])
        if facingEnabled, facingMode == .motionCue {
            cueStartedAt = .now
            startMixIfNeeded()
        } else {
            cueStartedAt = cueOverlayShown ? cueStartedAt : nil
            if !cueOverlayShown { mixTask?.cancel() }
        }
        if !facingEnabled { pausePrompt() }
    }

    func setFacingMode(_ new: FacingMode) {
        guard new != facingMode else { return }
        facingMode = new
        EventLog.log("facing_mode_changed", ["mode": new.rawValue])
        if new == .motionCue {
            cueStartedAt = .now
            startMixIfNeeded()
        } else {
            cueStartedAt = nil
            mixTask?.cancel()
        }
        if new != .prompt { pausePrompt() }
        if new == .off { facingEnabled = false }
    }

    func setCue(_ new: MotionCue) {
        cue = new
        cueStartedAt = .now
        evaluator.reset()
    }

    func cycleCue() {
        setCue(cue.next)
    }

    func setMixCues(_ on: Bool) {
        mixCues = on
        startMixIfNeeded()
    }

    private func startMixIfNeeded() {
        mixTask?.cancel()
        guard mixCues else { return }
        mixTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled, let self else { return }
                self.cycleCue()
            }
        }
    }

    func showCueOverlay(_ shown: Bool) {
        cueOverlayShown = shown
        if shown {
            cueStartedAt = .now
            startMixIfNeeded()
        } else if !facingIsLive || facingMode != .motionCue {
            cueStartedAt = nil
            mixTask?.cancel()
        }
    }

    // MARK: Prompt

    func promptElapsed(at date: Date) -> TimeInterval {
        if promptPlaying, let anchor = promptAnchor { return max(0, date.timeIntervalSince(anchor)) }
        return promptPausedElapsed
    }

    func playPrompt() {
        guard !promptPlaying else { return }
        promptAnchor = Date.now.addingTimeInterval(-promptPausedElapsed)
        promptPlaying = true
    }

    func pausePrompt() {
        guard promptPlaying else { return }
        promptPausedElapsed = promptElapsed(at: .now)
        promptPlaying = false
        promptAnchor = nil
    }

    func togglePrompt() {
        if promptPlaying { pausePrompt() } else { playPrompt() }
    }

    func restartPrompt() {
        promptPausedElapsed = 0
        promptAnchor = promptPlaying ? .now : nil
    }

    func selectPrompt(_ script: PromptScript?) {
        promptScriptID = script?.id
        restartPrompt()
    }

    // MARK: Still Hint

    private func updateHintTap() async {
        let wanted = status == .running && mode == .photo
        if wanted {
            if hint == .off { hint = .searching }
            await session.setFrameTap { [weak self] sample in
                Task { @MainActor in self?.ingest(sample) }
            }
        } else {
            hint = .off
            cancelAutoCapture()
            await session.setFrameTap(nil)
        }
    }

    func ingest(_ sample: FaceSample) {
        guard mode == .photo, case .running = status else { return }
        let ready = evaluator.ingest(sample)
        let next: HintState = ready ? .ready : .searching
        if next != hint {
            hint = next
            if ready { Haptics.tick(enabled: settings.hapticsOn) }
        }
        if ready {
            maybeAutoCapture()
        } else {
            cancelAutoCapture()
        }
    }

    /// Conservative gate: never while busy, never twice within 4s, and for Motion Cue only
    /// after the animation has had 2 seconds to do its job.
    private var autoCaptureArmed: Bool {
        if isCapturing || countdown != nil || isRecording || mode != .photo { return false }
        if let last = lastAutoCapture, Date.now.timeIntervalSince(last) < 4 { return false }
        let cueLive = (facingIsLive && facingMode == .motionCue) || cueOverlayShown
        if cueLive {
            return settings.cueAutoCapture && cueAge() >= 2
        }
        return autoCapture
    }

    private func maybeAutoCapture() {
        guard autoCaptureArmed, autoCaptureTask == nil else { return }
        autoCaptureWarning = 2
        autoCaptureTask = Task { [weak self] in
            var remaining = 2
            while remaining > 0 {
                guard let self else { return }
                self.autoCaptureWarning = remaining
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                remaining -= 1
            }
            guard let self else { return }
            self.autoCaptureWarning = nil
            self.autoCaptureTask = nil
            guard self.hint == .ready, self.autoCaptureArmed else { return }
            self.lastAutoCapture = .now
            EventLog.log("auto_capture")
            await self.capturePhoto()
        }
    }

    func cancelAutoCapture() {
        autoCaptureTask?.cancel()
        autoCaptureTask = nil
        autoCaptureWarning = nil
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
