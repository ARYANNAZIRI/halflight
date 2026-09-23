import AVFoundation
import UIKit

enum CameraError: LocalizedError {
    case noCamera
    case notRunning
    case cannotAddInput
    case cannotAddOutput
    case alreadyRecording
    case notRecording
    case noPhotoData

    var errorDescription: String? {
        switch self {
        case .noCamera: String(localized: "No camera is available on this device.")
        case .notRunning: String(localized: "The camera isn’t running.")
        case .cannotAddInput, .cannotAddOutput: String(localized: "The camera couldn’t be configured.")
        case .alreadyRecording: String(localized: "Already recording.")
        case .notRecording: String(localized: "Not recording.")
        case .noPhotoData: String(localized: "The photo came back empty.")
        }
    }
}

/// Owns the AVCaptureSession. Everything that touches AVFoundation runs on this actor;
/// the UI only ever sees Sendable snapshots and the preview source box.
actor CameraSession {
    enum Lens: String, CaseIterable, Codable, Sendable, Identifiable {
        case main, ultraWide, front
        var id: String { rawValue }
    }

    enum CaptureMode: String, CaseIterable, Sendable, Identifiable {
        case photo, video
        var id: String { rawValue }
    }

    enum FlashMode: String, CaseIterable, Sendable, Identifiable {
        case off, auto, on
        var id: String { rawValue }

        var av: AVCaptureDevice.FlashMode {
            switch self {
            case .off: .off
            case .auto: .auto
            case .on: .on
            }
        }
    }

    struct Capabilities: Sendable, Equatable {
        var hasUltraWide = false
        var hasFront = false
        var hasFlash = false
        var hasTorch = false
        var supports4K = false
        var supportsHDRVideo = false
        /// Display zoom for the ultra wide position (0.5 on a dual-wide rear module).
        var ultraWideZoom: CGFloat = 1
        var maxZoom: CGFloat = 1
        var minExposureBias: Float = -2
        var maxExposureBias: Float = 2
    }

    enum Event: Sendable {
        case interrupted(reason: String)
        case interruptionEnded
        case runtimeError(String)
        case recordingStarted
        case recordingFinished(URL)
        case recordingFailed(String)
    }

    struct CapturedPhoto: Sendable {
        let data: Data
    }

    /// AVCaptureSession is not Sendable. The preview layer reads it on the main thread and never
    /// mutates it; all configuration stays on this actor.
    struct PreviewSource: @unchecked Sendable {
        let session: AVCaptureSession
        let device: AVCaptureDevice?
        let position: AVCaptureDevice.Position
    }

    let events: AsyncStream<Event>
    private let eventsContinuation: AsyncStream<Event>.Continuation

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let frameOutput = AVCaptureVideoDataOutput()
    private let frameQueue = DispatchQueue(label: "app.halflight.frames", qos: .userInitiated)
    private let directions = CameraDirectionCoordinator()

    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var frameTap: FrameTap?
    private var photoProcessors: [Int64: PhotoCaptureProcessor] = [:]
    private var recordingDelegate: MovieRecordingDelegate?
    private var observers: [any NSObjectProtocol] = []

    private var isConfigured = false
    private(set) var lens: Lens = .main
    private(set) var mode: CaptureMode = .photo
    private(set) var capabilities = Capabilities()
    /// Zoom factor at which the rear virtual device switches from ultra wide to main.
    private var mainSwitchOver: CGFloat = 1

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
        events = stream
        eventsContinuation = continuation
    }

    deinit {
        eventsContinuation.finish()
    }

    // MARK: Lifecycle

    func configure(lens requested: Lens, mode requestedMode: CaptureMode) throws {
        session.beginConfiguration()
        var committed = false
        defer { if !committed { session.commitConfiguration() } }

        if !isConfigured {
            session.sessionPreset = .photo
            guard session.canAddOutput(photoOutput) else { throw CameraError.cannotAddOutput }
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .balanced

            frameOutput.alwaysDiscardsLateVideoFrames = true
            frameOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            if session.canAddOutput(frameOutput) {
                session.addOutput(frameOutput)
            }
            registerObservers()
            isConfigured = true
        }

        try applyLens(requested)
        applyMode(requestedMode)
        session.commitConfiguration()
        committed = true
        refreshPhotoDimensions()
    }

    func start() {
        guard isConfigured, !session.isRunning else { return }
        session.startRunning()
    }

    func stop() {
        if movieOutput.isRecording { movieOutput.stopRecording() }
        if session.isRunning { session.stopRunning() }
    }

    var isRunning: Bool { session.isRunning }

    func previewSource() -> PreviewSource {
        PreviewSource(
            session: session,
            device: videoInput?.device,
            position: videoInput?.device.position ?? .back
        )
    }

    // MARK: Lens, mode, zoom

    /// Returns the display zoom after the switch (1 = main, ultraWideZoom = ultra wide).
    @discardableResult
    func setLens(_ requested: Lens) throws -> CGFloat {
        session.beginConfiguration()
        do {
            try applyLens(requested)
        } catch {
            session.commitConfiguration()
            throw error
        }
        session.commitConfiguration()
        refreshPhotoDimensions()
        return displayZoom()
    }

    func setMode(_ requested: CaptureMode) {
        guard requested != mode else { return }
        session.beginConfiguration()
        applyMode(requested)
        session.commitConfiguration()
        refreshPhotoDimensions()
    }

    /// Must run after `commitConfiguration`: the preset decides the active format, and the
    /// photo output only accepts dimensions the active format supports.
    private func refreshPhotoDimensions() {
        guard mode == .photo, let device = videoInput?.device else { return }
        applyPhotoDimensions(for: device)
    }

    /// Clamps and applies a display zoom. Returns what was actually applied.
    @discardableResult
    func setZoom(display: CGFloat) -> CGFloat {
        guard let device = videoInput?.device else { return 1 }
        let raw = display * mainSwitchOver
        let lower = device.minAvailableVideoZoomFactor
        let upper = min(device.maxAvailableVideoZoomFactor, mainSwitchOver * 10)
        let clamped = min(max(raw, lower), upper)
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        } catch {
            return displayZoom()
        }
        return clamped / mainSwitchOver
    }

    func displayZoom() -> CGFloat {
        guard let device = videoInput?.device else { return 1 }
        return device.videoZoomFactor / mainSwitchOver
    }

    private func applyLens(_ requested: Lens) throws {
        let wantsFront = requested == .front
        let currentIsFront = videoInput?.device.position == .front

        if videoInput == nil || wantsFront != currentIsFront {
            guard let device = wantsFront ? directions.frontDevice() : directions.rearDevice() else {
                throw CameraError.noCamera
            }
            if let old = videoInput { session.removeInput(old) }
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
            session.addInput(input)
            videoInput = input
            rotation = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)

            if wantsFront {
                mainSwitchOver = 1
            } else {
                let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors
                mainSwitchOver = switchOvers.first.map { CGFloat(truncating: $0) } ?? 1
            }
            configureDeviceDefaults(device)
            updateCapabilities(for: device)
            if let tap = frameTap {
                tap.orientation = wantsFront ? .leftMirrored : .right
            }
        }

        lens = requested
        if let device = videoInput?.device {
            let target: CGFloat
            switch requested {
            case .main: target = mainSwitchOver
            case .ultraWide: target = capabilities.hasUltraWide ? 1 : mainSwitchOver
            case .front: target = 1
            }
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = min(max(target, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
                device.unlockForConfiguration()
            } catch {
                // Zoom is cosmetic here; keep going.
            }
        }
    }

    private func applyMode(_ requested: CaptureMode) {
        mode = requested
        switch requested {
        case .photo:
            if session.outputs.contains(movieOutput) { session.removeOutput(movieOutput) }
            if let audio = audioInput { session.removeInput(audio); audioInput = nil }
            session.sessionPreset = .photo
        case .video:
            if session.canSetSessionPreset(.hd4K3840x2160) {
                session.sessionPreset = .hd4K3840x2160
                capabilities.supports4K = true
            } else {
                session.sessionPreset = .high
                capabilities.supports4K = false
            }
            if audioInput == nil,
               AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
               let mic = AVCaptureDevice.default(for: .audio),
               let input = try? AVCaptureDeviceInput(device: mic),
               session.canAddInput(input) {
                session.addInput(input)
                audioInput = input
            }
            if !session.outputs.contains(movieOutput), session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
            }
            if let device = videoInput?.device {
                capabilities.supportsHDRVideo = device.activeFormat.isVideoHDRSupported
                if device.activeFormat.isVideoHDRSupported {
                    if (try? device.lockForConfiguration()) != nil {
                        device.automaticallyAdjustsVideoHDREnabled = true
                        device.unlockForConfiguration()
                    }
                }
            }
        }
    }

    private func configureDeviceDefaults(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.isSubjectAreaChangeMonitoringEnabled = true
        } catch {
            // Defaults are best-effort.
        }
    }

    private func applyPhotoDimensions(for device: AVCaptureDevice) {
        // Fast shutter beats megapixels here: cap around 24MP so 48MP sensors don't add latency.
        let supported = device.activeFormat.supportedMaxPhotoDimensions
        let capped = supported.filter { $0.width <= 5_800 }
        if let best = capped.last ?? supported.first {
            photoOutput.maxPhotoDimensions = best
        }
    }

    private func updateCapabilities(for device: AVCaptureDevice) {
        var caps = capabilities
        caps.hasUltraWide = device.position == .back && device.deviceType == .builtInDualWideCamera
        caps.ultraWideZoom = caps.hasUltraWide ? 1 / mainSwitchOver : 1
        caps.hasFront = directions.frontDevice() != nil
        caps.hasFlash = device.hasFlash
        caps.hasTorch = device.hasTorch
        caps.maxZoom = min(device.maxAvailableVideoZoomFactor, mainSwitchOver * 10) / mainSwitchOver
        caps.minExposureBias = device.minExposureTargetBias
        caps.maxExposureBias = device.maxExposureTargetBias
        capabilities = caps
    }

    // MARK: Focus, exposure, torch

    /// `point` is in capture-device coordinates (0...1, from the preview layer).
    func focus(at point: CGPoint) {
        guard let device = videoInput?.device else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
        } catch {
            // Focus is best-effort.
        }
    }

    private func resetFocus() {
        guard let device = videoInput?.device else { return }
        configureDeviceDefaults(device)
    }

    func setExposureBias(_ bias: Float) {
        guard let device = videoInput?.device else { return }
        let clamped = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)
        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(clamped)
            device.unlockForConfiguration()
        } catch {
            // Best-effort.
        }
    }

    func setTorch(_ on: Bool) {
        guard let device = videoInput?.device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on && device.isTorchModeSupported(.on) ? .on : .off
            device.unlockForConfiguration()
        } catch {
            // Best-effort.
        }
    }

    // MARK: Photo

    func capturePhoto(flash: FlashMode) async throws -> CapturedPhoto {
        guard session.isRunning else { throw CameraError.notRunning }

        let settings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settings = AVCapturePhotoSettings()
        }
        if photoOutput.supportedFlashModes.contains(flash.av) {
            settings.flashMode = flash.av
        }
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        settings.photoQualityPrioritization = .balanced

        if let connection = photoOutput.connection(with: .video), let rotation {
            let angle = rotation.videoRotationAngleForHorizonLevelCapture
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            if videoInput?.device.position == .front, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }

        let id = settings.uniqueID
        return try await withCheckedThrowingContinuation { continuation in
            let processor = PhotoCaptureProcessor(continuation: continuation) { [weak self] in
                Task { await self?.releaseProcessor(id) }
            }
            photoProcessors[id] = processor
            photoOutput.capturePhoto(with: settings, delegate: processor)
        }
    }

    private func releaseProcessor(_ id: Int64) {
        photoProcessors[id] = nil
    }

    // MARK: Video

    func startRecording(to url: URL) throws {
        guard session.isRunning else { throw CameraError.notRunning }
        guard mode == .video, session.outputs.contains(movieOutput) else { throw CameraError.notRunning }
        guard !movieOutput.isRecording else { throw CameraError.alreadyRecording }

        if let connection = movieOutput.connection(with: .video) {
            if let rotation {
                let angle = rotation.videoRotationAngleForHorizonLevelCapture
                if connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            }
            if movieOutput.availableVideoCodecTypes.contains(.hevc) {
                movieOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: connection)
            }
            if videoInput?.device.position == .front, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }

        let continuation = eventsContinuation
        let delegate = MovieRecordingDelegate { result in
            switch result {
            case .success(let finishedURL): continuation.yield(.recordingFinished(finishedURL))
            case .failure(let error): continuation.yield(.recordingFailed(error.localizedDescription))
            }
        }
        recordingDelegate = delegate
        movieOutput.startRecording(to: url, recordingDelegate: delegate)
        continuation.yield(.recordingStarted)
    }

    func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }

    var isRecording: Bool { movieOutput.isRecording }

    // MARK: Frames for Still Hint

    func setFrameTap(_ handler: (@Sendable (FaceSample) -> Void)?) {
        guard let handler else {
            frameOutput.setSampleBufferDelegate(nil, queue: nil)
            frameTap = nil
            return
        }
        let tap = FrameTap(handler: handler)
        tap.orientation = videoInput?.device.position == .front ? .leftMirrored : .right
        frameTap = tap
        frameOutput.setSampleBufferDelegate(tap, queue: frameQueue)
    }

    // MARK: Interruptions

    private func registerObservers() {
        let center = NotificationCenter.default
        let continuation = eventsContinuation

        observers.append(center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { note in
            let rawReason = note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int
            let reason = rawReason.flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
            continuation.yield(.interrupted(reason: Self.describe(reason)))
        })
        observers.append(center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil) { _ in
            continuation.yield(.interruptionEnded)
        })
        observers.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { note in
            let error = note.userInfo?[AVCaptureSessionErrorKey] as? NSError
            continuation.yield(.runtimeError(error?.localizedDescription ?? String(localized: "The camera stopped unexpectedly.")))
        })
        observers.append(center.addObserver(forName: AVCaptureDevice.subjectAreaDidChangeNotification, object: nil, queue: nil) { [weak self] _ in
            Task { await self?.resetFocus() }
        })
    }

    private static func describe(_ reason: AVCaptureSession.InterruptionReason?) -> String {
        switch reason {
        case .videoDeviceNotAvailableInBackground: String(localized: "Camera paused in the background.")
        case .audioDeviceInUseByAnotherClient: String(localized: "The microphone is in use by another app.")
        case .videoDeviceInUseByAnotherClient: String(localized: "The camera is in use by another app.")
        case .videoDeviceNotAvailableWithMultipleForegroundApps: String(localized: "The camera isn’t available in Split View right now.")
        case .videoDeviceNotAvailableDueToSystemPressure: String(localized: "The camera paused to cool down.")
        default: String(localized: "The camera paused.")
        }
    }
}

// MARK: - Delegates

/// One per capture. Resumes exactly once, then asks the actor to drop it.
private final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<CameraSession.CapturedPhoto, any Error>?
    private let onFinish: @Sendable () -> Void

    init(continuation: CheckedContinuation<CameraSession.CapturedPhoto, any Error>, onFinish: @escaping @Sendable () -> Void) {
        self.continuation = continuation
        self.onFinish = onFinish
    }

    private func resume(_ result: Result<CameraSession.CapturedPhoto, any Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(with: result)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        if let error {
            resume(.failure(error))
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            resume(.failure(CameraError.noPhotoData))
            return
        }
        resume(.success(CameraSession.CapturedPhoto(data: data)))
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: (any Error)?) {
        if let error { resume(.failure(error)) }
        onFinish()
    }
}

private final class MovieRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    private let completion: @Sendable (Result<URL, any Error>) -> Void

    init(completion: @escaping @Sendable (Result<URL, any Error>) -> Void) {
        self.completion = completion
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Error)?) {
        if let error {
            // The system can stop a recording (call, fold, background) and still hand back a good file.
            let nsError = error as NSError
            let finishedOK = (nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool) ?? false
            if finishedOK, FileManager.default.fileExists(atPath: outputFileURL.path) {
                completion(.success(outputFileURL))
            } else {
                completion(.failure(error))
            }
            return
        }
        completion(.success(outputFileURL))
    }
}
