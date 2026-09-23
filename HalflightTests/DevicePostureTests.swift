import Testing
@testable import Halflight

struct DevicePostureTests {
    @Test(arguments: [
        (0.0, DevicePosture.closed),
        (14.9, DevicePosture.closed),
        (15.0, DevicePosture.book),
        (79.9, DevicePosture.book),
        (80.0, DevicePosture.tent),
        (105.0, DevicePosture.tent),
        (130.0, DevicePosture.tent),
        (130.1, DevicePosture.open),
        (180.0, DevicePosture.open),
    ])
    func postureFromAngle(angle: Double, expected: DevicePosture) {
        #expect(DevicePosture.from(angle: angle) == expected)
    }

    @Test func partiallyOpenFlag() {
        #expect(DevicePosture.book.isPartiallyOpen)
        #expect(DevicePosture.tent.isPartiallyOpen)
        #expect(!DevicePosture.open.isPartiallyOpen)
        #expect(!DevicePosture.closed.isPartiallyOpen)
    }
}
