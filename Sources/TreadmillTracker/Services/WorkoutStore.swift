import Foundation
import Observation
import TreadmillKit

/// Workout history persisted as JSON in Documents (visible in the Files app).
@MainActor
@Observable
final class WorkoutStore {
    private(set) var records: [WorkoutRecord] = []
    private let url: URL

    init(url: URL = WorkoutStore.defaultURL) {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--app-store-screenshots") {
            // Isolated samples. Never read or overwrite the user's history.
            self.url = FileManager.default.temporaryDirectory.appendingPathComponent("screenshot-workouts.json")
            let today = Calendar.current.startOfDay(for: Date())
            records = (0..<3).map { day in
                let start = today.addingTimeInterval(Double(-day * 86400 + 8 * 3600))
                var session = WorkoutSession(speedKmh: 5, inclinePercent: 1, weightKg: 60)
                session.start(at: start)
                session.setSpeed(6, at: start.addingTimeInterval(300))
                session.setIncline(4, at: start.addingTimeInterval(600))
                session.setIncline(2, at: start.addingTimeInterval(1200))
                session.setSpeed(5, at: start.addingTimeInterval(1500))
                session.finish(at: start.addingTimeInterval(1800))
                return WorkoutRecord(session: session, programName: "傾斜ウォーキング", steps: 3200)!
            }
            return
        }
        #endif
        self.url = url
        load()
    }

    nonisolated static var defaultURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("workouts.json")
    }

    func add(_ record: WorkoutRecord) {
        records.removeAll { $0.id == record.id }
        records.append(record)
        records.sort { $0.startDate > $1.startDate }
        save()
    }

    func update(_ record: WorkoutRecord) {
        guard let i = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[i] = record
        save()
    }

    /// Import in one atomic write, preserving richer local records and avoiding legacy duplicates.
    @discardableResult
    func importHealthRecords(_ restored: [WorkoutRecord]) throws -> Int {
        let result = WorkoutRecord.mergingHealthRecords(restored, into: records)
        try WorkoutRecord.encodeList(result.records).write(to: url, options: .atomic)
        records = result.records
        return result.added
    }

    func delete(_ ids: Set<UUID>) {
        records.removeAll { ids.contains($0.id) }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        records = ((try? WorkoutRecord.decodeList(data)) ?? []).sorted { $0.startDate > $1.startDate }
    }

    private func save() {
        do {
            try WorkoutRecord.encodeList(records).write(to: url, options: .atomic)
        } catch {
            print("Failed to save workouts: \(error)")
        }
    }
}
