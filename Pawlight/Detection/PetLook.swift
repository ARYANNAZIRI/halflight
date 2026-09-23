import AVFoundation
import Foundation
import ImageIO
import QuartzCore
import Vision

/// One detection pass. Everything is Vision-normalized (0...1, origin bottom-left).
struct PetSample: Sendable, Equatable {
    enum Species: String, Sendable, Equatable {
        case cat, dog
    }

    /// Head landmarks that cleared the confidence bar. Missing points are nil.
    struct Head: Sendable, Equatable {
        var leftEye: CGPoint?
        var rightEye: CGPoint?
        var nose: CGPoint?
    }

    let time: TimeInterval
    let species: [Species]
    let heads: [Head]
}

/// What the viewfinder shows about the pet right now.
enum PetLook: Equatable, Sendable {
    /// No cat or dog in frame.
    case none
    /// A pet is in frame but not facing the lens.
    case seen
    /// Facing the lens and steady long enough to shoot.
    case looking
}

/// Pure decision logic for "Looking". Pets hold still for a fraction of what people do, so the
/// window is short (0.25s) and the drift allowance is wide; a missed frame beats a blurry one.
struct PetLookEvaluator: Sendable {
    var requiredLook: TimeInterval = 0.25
    /// Max drift of the eye midpoint between samples, as a fraction of the frame.
    var maxDrift: CGFloat = 0.05
    /// Eyes closer together than this fraction of the frame are too far away to be worth a shot.
    var minEyeSpan: CGFloat = 0.02

    private var facingSince: TimeInterval?
    private var lastCenter: CGPoint?

    init() {}

    mutating func ingest(_ sample: PetSample) -> PetLook {
        let facing = sample.heads
            .filter { Self.isFacing($0, minEyeSpan: minEyeSpan) }
            .max { Self.eyeSpan($0) < Self.eyeSpan($1) }

        guard let head = facing, let center = Self.eyeCenter(head) else {
            facingSince = nil
            lastCenter = nil
            return sample.species.isEmpty && sample.heads.isEmpty ? .none : .seen
        }

        defer { lastCenter = center }
        if let previous = lastCenter, hypot(center.x - previous.x, center.y - previous.y) > maxDrift {
            facingSince = sample.time
            return .seen
        }
        if facingSince == nil { facingSince = sample.time }
        guard let since = facingSince else { return .seen }
        return sample.time - since >= requiredLook ? .looking : .seen
    }

    mutating func reset() {
        facingSince = nil
        lastCenter = nil
    }

    /// Both eyes and the nose visible, and the nose sits between the eyes along the eye line and
    /// close to it. That holds for a frontal head at any roll, so it works in any orientation.
    static func isFacing(_ head: PetSample.Head, minEyeSpan: CGFloat) -> Bool {
        guard let left = head.leftEye, let right = head.rightEye, let nose = head.nose else { return false }
        let ex = right.x - left.x
        let ey = right.y - left.y
        let span2 = ex * ex + ey * ey
        guard span2 >= minEyeSpan * minEyeSpan else { return false }
        let nx = nose.x - left.x
        let ny = nose.y - left.y
        // Position of the nose along the eye line (0 = left eye, 1 = right eye).
        let along = (nx * ex + ny * ey) / span2
        // Distance of the nose from the eye line, in eye spans.
        let across = abs(nx * ey - ny * ex) / span2
        return along >= 0.2 && along <= 0.8 && across <= 1.3
    }

    static func eyeSpan(_ head: PetSample.Head) -> CGFloat {
        guard let left = head.leftEye, let right = head.rightEye else { return 0 }
        return hypot(right.x - left.x, right.y - left.y)
    }

    static func eyeCenter(_ head: PetSample.Head) -> CGPoint? {
        guard let left = head.leftEye, let right = head.rightEye else { return nil }
        return CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
    }
}

/// Runs Vision's cat/dog recognizer and animal body pose on a throttled stream of preview
/// frames, off the main thread. Plugs into Halflight's `CameraSession` as a `FrameAnalyzer`.
final class PetFrameAnalyzer: NSObject, FrameAnalyzer, @unchecked Sendable {
    private let handler: @Sendable (PetSample) -> Void
    private let animals = VNRecognizeAnimalsRequest()
    private let pose = VNDetectAnimalBodyPoseRequest()
    private var lastTime: CFTimeInterval = 0
    private let interval: CFTimeInterval = 0.1
    private let minConfidence: Float = 0.3
    var orientation: CGImagePropertyOrientation = .right

    init(handler: @escaping @Sendable (PetSample) -> Void) {
        self.handler = handler
        super.init()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastTime >= interval else { return }
        lastTime = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try request.perform([animals, pose])
        } catch {
            handler(PetSample(time: now, species: [], heads: []))
            return
        }

        let species: [PetSample.Species] = (animals.results ?? []).compactMap { observation in
            let identifier = observation.labels.first?.identifier ?? ""
            if identifier == VNAnimalIdentifier.cat.rawValue { return .cat }
            if identifier == VNAnimalIdentifier.dog.rawValue { return .dog }
            return nil
        }
        let heads: [PetSample.Head] = (pose.results ?? []).compactMap { observation in
            guard let points = try? observation.recognizedPoints(.head) else { return nil }
            func point(_ joint: VNAnimalBodyPoseObservation.JointName) -> CGPoint? {
                guard let found = points[joint], found.confidence >= minConfidence else { return nil }
                return found.location
            }
            let head = PetSample.Head(leftEye: point(.leftEye), rightEye: point(.rightEye), nose: point(.nose))
            return head.leftEye == nil && head.rightEye == nil && head.nose == nil ? nil : head
        }
        handler(PetSample(time: now, species: species, heads: heads))
    }
}
