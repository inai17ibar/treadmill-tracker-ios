import XCTest
@testable import TreadmillKit

final class ProgramRecordTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

    func testProgramPosition() {
        let p = WorkoutProgram(id: "t", name: "t", summary: "", steps: [
            ProgramStep("a", minutes: 1, speedKmh: 5),
            ProgramStep("b", minutes: 2, speedKmh: 10, inclinePercent: 2)
        ])
        XCTAssertEqual(p.totalDuration, 180)
        XCTAssertEqual(p.totalDistanceMeters, 5 / 3.6 * 60 + 10 / 3.6 * 120, accuracy: 1e-9)
        let a = p.position(atElapsed: 30)
        XCTAssertEqual(a.stepIndex, 0)
        XCTAssertEqual(a.remainingInStep, 30)
        XCTAssertEqual(a.next?.label, "b")
        let b = p.position(atElapsed: 60)
        XCTAssertEqual(b.stepIndex, 1)
        XCTAssertNil(b.next)
        XCTAssertTrue(p.position(atElapsed: 180).isComplete)
        XCTAssertEqual(p.scaledSpeed(by: 0.9).steps.map(\.speedKmh), [4.5, 9])
    }

    func testPresetsAreValid() {
        XCTAssertFalse(WorkoutProgram.presets.isEmpty)
        XCTAssertEqual(Set(WorkoutProgram.presets.map(\.id)).count, WorkoutProgram.presets.count)
        for p in WorkoutProgram.presets {
            XCTAssertFalse(p.steps.isEmpty, p.name)
            for s in p.steps {
                XCTAssertTrue(TreadmillLimits.speedKmh.contains(s.speedKmh), p.name)
                XCTAssertTrue(TreadmillLimits.inclinePercent.contains(s.inclinePercent), p.name)
                XCTAssertGreaterThan(s.duration, 0)
            }
        }
        let classic = WorkoutProgram.presets.first { $0.id == "12-3-30" }!
        XCTAssertEqual(classic.totalDuration, 1800)
    }

    func testGoalProgress() {
        var s = WorkoutSession(speedKmh: 6, inclinePercent: 0, weightKg: 60)
        s.start(at: at(0))
        let m = s.metrics(at: at(300))
        XCTAssertNil(WorkoutGoal.none.progress(m))
        XCTAssertEqual(WorkoutGoal.duration(600).progress(m)!, 0.5, accuracy: 1e-9)
        XCTAssertEqual(WorkoutGoal.distance(meters: 1000).progress(m)!, 0.5, accuracy: 1e-9)
        XCTAssertTrue(WorkoutGoal.distance(meters: 400).isReached(m))
    }

    func testRecordCorrectionAndCoding() throws {
        var s = WorkoutSession(speedKmh: 6, inclinePercent: 0, weightKg: 60)
        s.start(at: at(0))
        s.setSpeed(9, at: at(600))
        s.finish(at: at(1200))
        let r = try XCTUnwrap(WorkoutRecord(session: s, programName: nil, steps: 3000))
        XCTAssertEqual(r.metrics.distanceMeters, 2500, accuracy: 1e-6)
        XCTAssertEqual(r.primaryGait, .walk)
        XCTAssertEqual(r.title, "ウォーキング")
        let fixed = r.correctingDistance(to: 2000)
        XCTAssertEqual(fixed.metrics.distanceMeters, 2000, accuracy: 1e-6)
        XCTAssertEqual(fixed.distanceCorrection, 0.8, accuracy: 1e-9)
        XCTAssertLessThan(fixed.metrics.activeKcal, r.metrics.activeKcal)

        let decoded = try WorkoutRecord.decodeList(WorkoutRecord.encodeList([fixed]))
        XCTAssertEqual(decoded, [fixed])

        XCTAssertNil(WorkoutRecord(session: WorkoutSession(speedKmh: 5, inclinePercent: 0, weightKg: 60)))
    }

    func testWeeklyTotals() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let seg = { (d: Date) in [WorkoutSegment(start: d, end: d.addingTimeInterval(600), speedKmh: 6, inclinePercent: 0, gait: .walk)] }
        let monday = cal.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 10))!
        let lastWeek = monday.addingTimeInterval(-7 * 86400)
        let records = [monday, lastWeek].map { WorkoutRecord(startDate: $0, endDate: $0.addingTimeInterval(600), segments: seg($0), weightKg: 60) }
        let totals = WorkoutTotals.week(of: monday.addingTimeInterval(86400), records: records, calendar: cal)
        XCTAssertEqual(totals.count, 1)
        XCTAssertEqual(totals.distanceMeters, 1000, accuracy: 1e-6)
    }

    func testStepMetrics() {
        XCTAssertEqual(StepMetrics.strideMeters(distanceMeters: 1000, steps: 1400)!, 1000 / 1400, accuracy: 1e-9)
        XCTAssertEqual(StepMetrics.cadence(steps: 300, duration: 120)!, 150, accuracy: 1e-9)
        XCTAssertNil(StepMetrics.cadence(steps: 0, duration: 60))
    }
}
