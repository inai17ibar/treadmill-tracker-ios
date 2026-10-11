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

    func testHealthArchiveRestoresIntervalsPausesAndCorrection() throws {
        var session = WorkoutSession(speedKmh: 6, inclinePercent: 3, weightKg: 73)
        session.start(at: at(0))
        session.pause(at: at(300))
        session.resume(at: at(360))
        session.setSpeed(10, at: at(600))
        session.finish(at: at(900))
        let record = try XCTUnwrap(WorkoutRecord(session: session, programName: "インターバル", steps: 1800))
            .correctingDistance(to: 1800)
        let header = try JSONDecoder().decode(WorkoutHealthArchive.self,
                                              from: JSONEncoder().encode(WorkoutHealthArchive(record)))
        let samples = try JSONDecoder().decode([WorkoutSegment].self, from: JSONEncoder().encode(record.segments))
        var expected = record
        expected.savedToHealth = true
        let restored = try header.restoring(segments: samples)
        XCTAssertEqual(restored, expected)
        XCTAssertEqual(restored.metrics.activeDuration, 840)
        XCTAssertEqual(restored.metrics.distanceMeters, 1800, accuracy: 1e-6)
        XCTAssertThrowsError(try header.restoring(segments: Array(samples.dropLast())))
        XCTAssertThrowsError(try header.restoring(segments: Array(samples.reversed())))
    }

    func testHealthSummaryUsesActualTotalsAndSurvivesLocalPersistence() throws {
        var record = WorkoutRecord(startDate: at(0), endDate: at(700), segments: [], weightKg: 0, savedToHealth: true)
        record.healthSummary = HealthWorkoutSummary(duration: 600, distanceMeters: 1250,
                                                    activeKcal: 87, elevationMeters: 25, gait: .run)
        let restored = try XCTUnwrap(WorkoutRecord.decodeList(WorkoutRecord.encodeList([record])).first)
        XCTAssertEqual(restored, record)
        XCTAssertEqual(restored.metrics.activeDuration, 600)
        XCTAssertEqual(restored.metrics.distanceMeters, 1250)
        XCTAssertEqual(restored.metrics.activeKcal, 87)
        XCTAssertEqual(restored.metrics.elevationMeters, 25)
        XCTAssertEqual(restored.primaryGait, .run)
        XCTAssertTrue(restored.segments.isEmpty)
        XCTAssertEqual(restored.correctingDistance(to: 2000), restored)
    }

    func testRepeatedRestorationPreservesLocalDetailsAndLegacyIDs() throws {
        let segment = WorkoutSegment(start: at(0), end: at(600), speedKmh: 6, inclinePercent: 4, gait: .walk)
        let local = WorkoutRecord(startDate: at(0), endDate: at(600), segments: [segment], weightKg: 60,
                                  steps: 1000, savedToHealth: true)
        var oldHealth = WorkoutRecord(startDate: at(0.4), endDate: at(600.4), segments: [], weightKg: 0, savedToHealth: true)
        oldHealth.healthSummary = HealthWorkoutSummary(duration: 600, distanceMeters: 1000,
                                                      activeKcal: 80, elevationMeters: nil, gait: .walk)
        let merged = WorkoutRecord.mergingHealthRecords([oldHealth, oldHealth], into: [local])
        XCTAssertEqual(merged.added, 0)
        XCTAssertEqual(merged.records, [local])

        let firstRestore = WorkoutRecord.mergingHealthRecords([local, local], into: [])
        XCTAssertEqual(firstRestore.added, 1)
        XCTAssertEqual(firstRestore.records, [local])
        var summary = oldHealth
        summary.id = local.id
        let upgraded = WorkoutRecord.mergingHealthRecords([local], into: [summary])
        XCTAssertEqual(upgraded.records, [local])
        XCTAssertEqual(upgraded.added, 0)
    }

    func testOldLocalJSONLoadsWithoutHealthSummary() throws {
        let record = WorkoutRecord(startDate: at(0), endDate: at(600), segments: [], weightKg: 60)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: WorkoutRecord.encodeList([record])) as? [[String: Any]])
        object[0].removeValue(forKey: "healthSummary")
        let decoded = try WorkoutRecord.decodeList(JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded, [record])
        XCTAssertNil(decoded.first?.healthSummary)
    }
}
