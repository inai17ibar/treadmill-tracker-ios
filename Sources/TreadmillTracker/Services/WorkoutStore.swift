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
