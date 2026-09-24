import AVFoundation
import Foundation
import QuartzCore
import Vision

/// One detection pass. Boxes are Vision-normalized (0...1, origin bottom-left).
struct FaceSample: Sendable, Equatable {
    struct Face: Sendable, Equatable {
        let box: CGRect
        /// Radians. nil when the detector couldn't estimate it.
        let yaw: Double?
    }

    let time: TimeInterval
    let faces: [Face]
}

/// Pure decision logic for "Ready": at least one reasonably frontal face, low motion for ~0.6s.
/// Conservative on purpose. A false shutter is worse than a missed moment.
struct StillHintEvaluator: Sendable {
    var requiredStill: TimeInterval = 0.6
    /// Max centre drift between consecutive samples, as a fraction of the frame.
    var maxDrift: CGFloat = 0.02
    /// Max yaw before a face stops counting as frontal (~30°).
    var maxYaw: Double = .pi / 6
    /// Faces smaller than this fraction of the frame width are ignored.
    var minFaceWidth: CGFloat = 0.08

    private var stableSince: TimeInterval?
    private var lastCenter: CGPoint?

    init() {}

    /// Returns true while the scene has been steady long enough to shoot.
    mutating func ingest(_ sample: FaceSample) -> Bool {
        guard let face = sample.faces
            .filter({ $0.box.width >= minFaceWidth })
            .filter({ abs($0.yaw ?? 0) <= maxYaw })
            .max(by: { $0.box.width < $1.box.width })
        else {
            reset()
            return false
        }

        let center = CGPoint(x: face.box.midX, y: face.box.midY)
        defer { lastCenter = center }

        guard let previous = lastCenter else {
            stableSince = nil
            return false
        }

        let drift = hypot(center.x - previous.x, center.y - previous.y)
        if drift > maxDrift {
            stableSince = nil
            return false
        }
        if stableSince == nil { stableSince = sample.time }
        guard let since = stableSince else { return false }
        return sample.time - since >= requiredStill
    }

    mutating func reset() {
        stableSince = nil
        lastCenter = nil
    }
}

/// Runs Vision face detection on a throttled stream of preview frames, off the main thread.
final class FrameTap: NSObject, FrameAnalyzer, @unchecked Sendable {
    private let handler: @Sendable (FaceSample) -> Void
    private let request = VNDetectFaceRectanglesRequest()
    private var lastTime: CFTimeInterval = 0
    private let interval: CFTimeInterval = 0.12
    var orientation: CGImagePropertyOrientation = .right

    init(handler: @escaping @Sendable (FaceSample) -> Void) {
        self.handler = handler
        super.init()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastTime >= interval else { return }
        lastTime = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handlerForFrame = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handlerForFrame.perform([request])
        } catch {
            handler(FaceSample(time: now, faces: []))
            return
        }
        let faces = (request.results ?? []).map { observation in
            FaceSample.Face(box: observation.boundingBox, yaw: observation.yaw?.doubleValue)
        }
        handler(FaceSample(time: now, faces: faces))
    }
}
