import Foundation
import Testing
@testable import Halflight

struct StillHintEvaluatorTests {
    private func face(x: CGFloat, y: CGFloat, width: CGFloat = 0.3, yaw: Double? = 0) -> FaceSample.Face {
        FaceSample.Face(box: CGRect(x: x, y: y, width: width, height: width * 1.3), yaw: yaw)
    }

    @Test func readyAfterSteadyWindow() {
        var evaluator = StillHintEvaluator()
        var ready = false
        for step in 0..<10 {
            let t = Double(step) * 0.1
            ready = evaluator.ingest(FaceSample(time: t, faces: [face(x: 0.35, y: 0.35)]))
        }
        #expect(ready)
    }

    @Test func notReadyBeforeWindow() {
        var evaluator = StillHintEvaluator()
        var ready = false
        for step in 0..<4 {
            ready = evaluator.ingest(FaceSample(time: Double(step) * 0.1, faces: [face(x: 0.35, y: 0.35)]))
        }
        #expect(!ready)
    }

    @Test func motionResetsTheClock() {
        var evaluator = StillHintEvaluator()
        for step in 0..<6 {
            _ = evaluator.ingest(FaceSample(time: Double(step) * 0.1, faces: [face(x: 0.35, y: 0.35)]))
        }
        let moved = evaluator.ingest(FaceSample(time: 0.6, faces: [face(x: 0.5, y: 0.35)]))
        #expect(!moved)
        var ready = false
        for step in 7..<11 {
            ready = evaluator.ingest(FaceSample(time: Double(step) * 0.1, faces: [face(x: 0.5, y: 0.35)]))
        }
        #expect(!ready)
    }

    @Test func noFaceIsNeverReady() {
        var evaluator = StillHintEvaluator()
        var ready = false
        for step in 0..<20 {
            ready = evaluator.ingest(FaceSample(time: Double(step) * 0.1, faces: []))
        }
        #expect(!ready)
    }

    @Test func turnedAwayFaceIsIgnored() {
        var evaluator = StillHintEvaluator()
        var ready = false
        for step in 0..<20 {
            ready = evaluator.ingest(FaceSample(time: Double(step) * 0.1, faces: [face(x: 0.35, y: 0.35, yaw: 1.2)]))
        }
        #expect(!ready)
    }

    @Test func tinyFaceIsIgnored() {
        var evaluator = StillHintEvaluator()
        var ready = false
        for step in 0..<20 {
            ready = evaluator.ingest(FaceSample(time: Double(step) * 0.1, faces: [face(x: 0.35, y: 0.35, width: 0.03)]))
        }
        #expect(!ready)
    }
}
