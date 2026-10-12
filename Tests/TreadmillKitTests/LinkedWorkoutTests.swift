import XCTest
@testable import TreadmillKit

final class LinkedWorkoutTests: XCTestCase {
    func testOrderingTerminalAndStaleCommands() {
        let now = Date(), id = UUID()
        let running = LinkedWorkout(id: id, start: now, updated: now, state: .running, running: false)
        let paused = LinkedWorkout(id: id, start: now, updated: now.addingTimeInterval(1), state: .paused, running: false)
        XCTAssertTrue(paused.canReplace(running, now: now))
        XCTAssertFalse(running.canReplace(paused, now: now))
        var finished = paused; finished.state = .finished; finished.updated = now.addingTimeInterval(2)
        var delayed = running; delayed.updated = now.addingTimeInterval(3)
        XCTAssertFalse(delayed.canReplace(finished, now: now))
        XCTAssertFalse(running.canReplace(nil, now: now.addingTimeInterval(100)))
        XCTAssertTrue(finished.canReplace(nil, now: now.addingTimeInterval(100)))
    }
    func testPhoneHeartFragmentHasStableIDAndCompactHealthArchive() throws {
        var record = WorkoutRecord(startDate: Date(), endDate: Date(), segments: [], weightKg: 60)
        record.linkedPhone = true
        record.heartRate = [.init(date: Date(), bpm: 125)]
        let restored = try WorkoutRecord.decodeList(WorkoutRecord.encodeList([record]))[0]
        XCTAssertEqual(record.id, restored.id)
        XCTAssertEqual(restored.linkedPhone, true)
        let metadata = try JSONEncoder().encode(WorkoutHealthArchive(record))
        XCTAssertFalse(String(decoding: metadata, as: UTF8.self).contains("bpm"))
    }
}
