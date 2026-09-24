import Foundation
import Testing
@testable import Pawlight

struct PetLookEvaluatorTests {
    /// A frontal head: eyes level, nose centred just below them.
    private func frontal(dx: CGFloat = 0, span: CGFloat = 0.1) -> PetSample.Head {
        PetSample.Head(
            leftEye: CGPoint(x: 0.5 - span / 2 + dx, y: 0.6),
            rightEye: CGPoint(x: 0.5 + span / 2 + dx, y: 0.6),
            nose: CGPoint(x: 0.5 + dx, y: 0.53)
        )
    }

    private func sample(_ t: TimeInterval, _ heads: [PetSample.Head], species: [PetSample.Species] = [.dog]) -> PetSample {
        PetSample(time: t, species: species, heads: heads)
    }

    @Test func noPetIsNone() {
        var evaluator = PetLookEvaluator()
        #expect(evaluator.ingest(sample(0, [], species: [])) == .none)
    }

    @Test func petWithoutHeadIsSeen() {
        var evaluator = PetLookEvaluator()
        #expect(evaluator.ingest(sample(0, [])) == .seen)
    }

    @Test func lookingAfterShortSteadyWindow() {
        var evaluator = PetLookEvaluator()
        var look = PetLook.none
        for step in 0..<4 {
            look = evaluator.ingest(sample(Double(step) * 0.1, [frontal()]))
        }
        #expect(look == .looking)
    }

    @Test func notLookingBeforeWindow() {
        var evaluator = PetLookEvaluator()
        var look = PetLook.none
        for step in 0..<3 {
            look = evaluator.ingest(sample(Double(step) * 0.1, [frontal()]))
        }
        #expect(look == .seen)
    }

    @Test func movementRestartsTheWindow() {
        var evaluator = PetLookEvaluator()
        for step in 0..<3 {
            _ = evaluator.ingest(sample(Double(step) * 0.1, [frontal()]))
        }
        #expect(evaluator.ingest(sample(0.3, [frontal(dx: 0.2)])) == .seen)
        #expect(evaluator.ingest(sample(0.4, [frontal(dx: 0.2)])) == .seen)
        #expect(evaluator.ingest(sample(0.6, [frontal(dx: 0.2)])) == .looking)
    }

    @Test func profileIsNotFacing() {
        let profile = PetSample.Head(
            leftEye: CGPoint(x: 0.45, y: 0.6),
            rightEye: CGPoint(x: 0.55, y: 0.6),
            nose: CGPoint(x: 0.64, y: 0.55)
        )
        #expect(!PetLookEvaluator.isFacing(profile, minEyeSpan: 0.02))
    }

    @Test func missingEyeIsNotFacing() {
        let head = PetSample.Head(leftEye: CGPoint(x: 0.45, y: 0.6), rightEye: nil, nose: CGPoint(x: 0.5, y: 0.53))
        #expect(!PetLookEvaluator.isFacing(head, minEyeSpan: 0.02))
    }

    @Test func tinyHeadIsIgnored() {
        #expect(!PetLookEvaluator.isFacing(frontal(span: 0.01), minEyeSpan: 0.02))
    }

    @Test func rolledHeadStillCounts() {
        // Same frontal face rotated 90° (phone held sideways): eyes stacked, nose beside them.
        let rolled = PetSample.Head(
            leftEye: CGPoint(x: 0.6, y: 0.45),
            rightEye: CGPoint(x: 0.6, y: 0.55),
            nose: CGPoint(x: 0.53, y: 0.5)
        )
        #expect(PetLookEvaluator.isFacing(rolled, minEyeSpan: 0.02))
    }

    @Test func picksTheLargestFacingHead() {
        var evaluator = PetLookEvaluator()
        let near = frontal(span: 0.2)
        let far = frontal(dx: 0.3, span: 0.05)
        var look = PetLook.none
        for step in 0..<4 {
            // The far head jumps around; the near one is steady and should win.
            let jitter = step.isMultiple(of: 2) ? far : frontal(dx: -0.3, span: 0.05)
            look = evaluator.ingest(sample(Double(step) * 0.1, [jitter, near]))
        }
        #expect(look == .looking)
    }
}
