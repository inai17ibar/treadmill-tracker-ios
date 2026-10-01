import XCTest
@testable import TreadmillKit

final class MetabolicTests: XCTestCase {
    func testWalkingEquation() {
        // 6 km/h = 100 m/min, 5% grade: 0.1*100 + 1.8*100*0.05 + 3.5 = 22.5
        XCTAssertEqual(Metabolic.vo2(speedKmh: 6, inclinePercent: 5, gait: .walk), 22.5, accuracy: 1e-9)
        let r = Metabolic.rate(speedKmh: 6, inclinePercent: 5, gait: .walk, weightKg: 70)
        XCTAssertEqual(r.grossKcalPerMinute, 22.5 * 70 / 1000 * 5, accuracy: 1e-9)
        XCTAssertEqual(r.activeKcalPerMinute, 19.0 * 70 / 1000 * 5, accuracy: 1e-9)
        XCTAssertEqual(r.mets, 22.5 / 3.5, accuracy: 1e-9)
    }

    func testRunningEquation() {
        // 12 km/h = 200 m/min, 1% grade: 0.2*200 + 0.9*200*0.01 + 3.5 = 45.3
        XCTAssertEqual(Metabolic.vo2(speedKmh: 12, inclinePercent: 1, gait: .run), 45.3, accuracy: 1e-9)
    }

    func testDeclineAndStopped() {
        XCTAssertEqual(Metabolic.vo2(speedKmh: 6, inclinePercent: -3, gait: .walk),
                       Metabolic.vo2(speedKmh: 6, inclinePercent: 0, gait: .walk))
        XCTAssertEqual(Metabolic.rate(speedKmh: 0, inclinePercent: 10, gait: .walk, weightKg: 60).activeKcalPerMinute, 0)
    }

    func testAutoGait() {
        XCTAssertEqual(GaitMode.auto.resolve(speedKmh: 6), .walk)
        XCTAssertEqual(GaitMode.auto.resolve(speedKmh: 8), .run)
        XCTAssertEqual(GaitMode.walk.resolve(speedKmh: 10), .walk)
    }

    func testUnitsAndFormat() {
        XCTAssertEqual(UnitSystem.imperial.speed(fromKmh: 4.828032), 3, accuracy: 1e-6)
        XCTAssertEqual(UnitSystem.metric.pace(speedKmh: 10)!, 360, accuracy: 1e-9)
        XCTAssertEqual(UnitSystem.metric.paceText(speedKmh: 10), "6'00\"")
        XCTAssertEqual(UnitSystem.metric.paceText(speedKmh: 0), "--'--\"")
        XCTAssertEqual(Format.duration(65), "1:05")
        XCTAssertEqual(Format.duration(3723), "1:02:03")
        XCTAssertEqual(TreadmillLimits.clampSpeed(30), 25)
        XCTAssertEqual(TreadmillLimits.clampIncline(-10), -3)
    }
}
