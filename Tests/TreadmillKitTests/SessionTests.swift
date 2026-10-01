import XCTest
@testable import TreadmillKit

final class SessionTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

    func testDistanceWithSpeedChangeAndPause() {
        var s = WorkoutSession(speedKmh: 6, inclinePercent: 0, gaitMode: .auto, weightKg: 60)
        s.start(at: at(0))
        s.setSpeed(12, at: at(600))   // 10 min @ 6 km/h = 1000 m
        s.pause(at: at(900))          // 5 min @ 12 km/h = 1000 m
        XCTAssertEqual(s.metrics(at: at(1200)).activeDuration, 900, accuracy: 1e-9)
        s.resume(at: at(1200))
        XCTAssertEqual(s.metrics(at: at(1500)).distanceMeters, 3000, accuracy: 1e-6)
        s.finish(at: at(1500))        // 5 min @ 12 km/h = 1000 m
        XCTAssertEqual(s.state, .finished)
        XCTAssertEqual(s.segments.count, 3)
        XCTAssertEqual(s.segments[0].gait, .walk)
        XCTAssertEqual(s.segments[1].gait, .run)
        let m = s.metrics(at: at(9999))
        XCTAssertEqual(m.distanceMeters, 3000, accuracy: 1e-6)
        XCTAssertEqual(m.activeDuration, 1200, accuracy: 1e-9)
        XCTAssertEqual(m.averageSpeedKmh, 9, accuracy: 1e-9)
        // walk: 10 min * (0.1*100)*60/1000*5 = 30 ; run: 10 min * (0.2*200)*60/1000*5 = 120
        XCTAssertEqual(m.activeKcal, 150, accuracy: 1e-6)
    }

    func testInclineElevationAndNoOpChanges() {
        var s = WorkoutSession(speedKmh: 4.8, inclinePercent: 12, weightKg: 70)
        s.start(at: at(0))
        s.setSpeed(4.8, at: at(10))
        s.setIncline(12, at: at(20))
        s.finish(at: at(1800))
        XCTAssertEqual(s.segments.count, 1)
        let d = 4.8 / 3.6 * 1800
        XCTAssertEqual(s.metrics(at: at(1800)).elevationMeters, d * 0.12 / (1 + 0.0144).squareRoot(), accuracy: 1e-6)
    }

    func testChangesWhilePausedAndClamping() {
        var s = WorkoutSession(speedKmh: 5, inclinePercent: 0, weightKg: 60)
        s.start(at: at(0))
        s.pause(at: at(60))
        s.setSpeed(40, at: at(70))
        XCTAssertEqual(s.speedKmh, 25)
        s.resume(at: at(120))
        s.finish(at: at(180))
        XCTAssertEqual(s.segments.map(\.speedKmh), [5, 25])
        XCTAssertEqual(s.segments[1].start, at(120))
    }

    func testIgnoresInvalidTransitions() {
        var s = WorkoutSession(speedKmh: 5, inclinePercent: 0, weightKg: 60)
        s.pause(at: at(0))
        s.finish(at: at(0))
        XCTAssertEqual(s.state, .ready)
        s.start(at: at(0))
        s.start(at: at(100))
        XCTAssertEqual(s.startDate, at(0))
    }

    func testSplits() {
        let seg = [
            WorkoutSegment(start: at(0), end: at(600), speedKmh: 6, inclinePercent: 0, gait: .walk),   // 1000 m
            WorkoutSegment(start: at(600), end: at(900), speedKmh: 12, inclinePercent: 0, gait: .run)  // 1000 m
        ]
        let splits = Splits.compute(seg + [WorkoutSegment(start: at(900), end: at(990), speedKmh: 12, inclinePercent: 0, gait: .run)],
                                    unitMeters: 1000)
        XCTAssertEqual(splits.count, 3)
        XCTAssertEqual(splits[0].duration, 600, accuracy: 1e-6)
        XCTAssertEqual(splits[1].duration, 300, accuracy: 1e-6)
        XCTAssertEqual(splits[2].distanceMeters, 300, accuracy: 1e-6)
        XCTAssertEqual(splits[2].duration, 90, accuracy: 1e-6)

        let half = Splits.compute([WorkoutSegment(start: at(0), end: at(600), speedKmh: 9, inclinePercent: 0, gait: .run)],
                                  unitMeters: 1000)
        XCTAssertEqual(half.map(\.duration).map { ($0 * 1000).rounded() / 1000 }, [400, 200])
    }
}
