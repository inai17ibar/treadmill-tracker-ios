import XCTest
@testable import TreadmillKit

final class HeartRateGuideTests: XCTestCase {
    func testWarmupPersistenceCooldownAndStaleData() {
        var guide = HeartRateGuide()
        let start = Date(timeIntervalSince1970: 1000)
        var settings = HeartRateSettings()
        settings.lower = 100; settings.upper = 140
        guide.ingest(.init(date: start, bpm: 160), now: start)
        XCTAssertEqual(guide.evaluate(now: start, activeSeconds: 10, paused: false, settings: settings).0, .warmup)
        for second in 0...16 {
            let now = start.addingTimeInterval(Double(second))
            guide.ingest(.init(date: now, bpm: 160), now: now)
            let result = guide.evaluate(now: now, activeSeconds: 120 + Double(second), paused: false, settings: settings)
            if second == 15 { XCTAssertEqual(result.0, .high); XCTAssertTrue(result.1) }
            if second == 16 { XCTAssertFalse(result.1) }
        }
        XCTAssertEqual(guide.evaluate(now: start.addingTimeInterval(50), activeSeconds: 170, paused: false, settings: settings).0, .waiting)
        XCTAssertEqual(guide.evaluate(now: start, activeSeconds: 170, paused: true, settings: settings).0, .paused)
    }
    func testInvalidSettingsAndSamplesNeverGuide() {
        var guide = HeartRateGuide(); var settings = HeartRateSettings()
        let now = Date()
        guide.ingest(.init(date: now, bpm: .nan), now: now)
        XCTAssertTrue(guide.points.isEmpty)
        guide.ingest(.init(date: now.addingTimeInterval(-60), bpm: 120), now: now)
        XCTAssertTrue(guide.points.isEmpty)
        settings.upper = settings.lower
        XCTAssertFalse(settings.isValid)
        XCTAssertEqual(guide.evaluate(now: now, activeSeconds: 200, paused: false, settings: settings).0, .waiting)
    }
    func testHeartRateHistoryRoundTripAndLegacyCompatibility() throws {
        var record = WorkoutRecord(startDate: Date(), endDate: Date(), segments: [], weightKg: 60)
        record.heartRate = [.init(date: Date(), bpm: 123)]
        let restored = try WorkoutRecord.decodeList(WorkoutRecord.encodeList([record]))
        XCTAssertEqual(restored.first?.heartRate?.first?.bpm, 123)
        record.heartRate = nil
        XCTAssertNil(try WorkoutRecord.decodeList(WorkoutRecord.encodeList([record])).first?.heartRate)
    }
}
