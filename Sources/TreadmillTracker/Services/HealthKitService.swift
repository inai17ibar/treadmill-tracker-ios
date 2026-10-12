import Foundation
import HealthKit
import TreadmillKit

/// Saves treadmill workouts to Apple Health (indoor walking / running) and reads the user's weight and height.
@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private var savingIDs: Set<UUID> = []
    private static let archiveKey = "com.inai17ibar.TreadmillTracker.archive"
    private static let segmentKey = "com.inai17ibar.TreadmillTracker.segment"

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKQuantityType(.distanceWalkingRunning), HKQuantityType(.activeEnergyBurned)]
    }

    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.bodyMass), HKQuantityType(.height), HKObjectType.workoutType(),
         HKQuantityType(.distanceWalkingRunning), HKQuantityType(.activeEnergyBurned)]
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    func canSaveWorkouts() -> Bool {
        isAvailable && store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    func latestWeightKg() async throws -> Double? {
        try await latest(.bodyMass)?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }

    func latestHeightCm() async throws -> Double? {
        try await latest(.height)?.quantity.doubleValue(for: .meterUnit(with: .centi))
    }

    private func latest(_ id: HKQuantityTypeIdentifier) async throws -> HKQuantitySample? {
        guard isAvailable else { return nil }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(id))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1)
        return try await descriptor.result(for: store).first
    }

    func save(_ record: WorkoutRecord) async throws {
        guard !record.savedToHealth else { return }
        guard isAvailable else { throw HealthError.unavailable }
        guard savingIDs.insert(record.id).inserted else { throw HealthError.saveInProgress }
        defer { savingIDs.remove(record.id) }
        try await requestAuthorization()
        // A prior save may have finished before the local saved flag was persisted.
        if try await existingWorkout(for: record) != nil { return }

        let config = HKWorkoutConfiguration()
        config.activityType = record.primaryGait == .run ? .running : .walking
        config.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: record.startDate)

        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let energyType = HKQuantityType(.activeEnergyBurned)
        var samples: [HKSample] = []
        for (index, seg) in record.segments.enumerated() where seg.duration > 0 {
            var distanceMetadata = syncMetadata(record.id, component: "distance-\(index)")
            distanceMetadata[Self.segmentKey] = try metadataString(seg)
            samples.append(HKQuantitySample(type: distanceType,
                                            quantity: HKQuantity(unit: .meter(), doubleValue: seg.distanceMeters),
                                            start: seg.start, end: seg.end,
                                            metadata: distanceMetadata))
            samples.append(HKQuantitySample(type: energyType,
                                            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: seg.activeKcal(weightKg: record.weightKg)),
                                            start: seg.start, end: seg.end,
                                            metadata: syncMetadata(record.id, component: "energy-\(index)")))
        }
        if !samples.isEmpty {
            try await builder.addSamples(samples)
        }

        var events: [HKWorkoutEvent] = []
        for (prev, next) in zip(record.segments, record.segments.dropFirst()) where next.start > prev.end {
            events.append(HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: prev.end, duration: 0), metadata: nil))
            events.append(HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: next.start, duration: 0), metadata: nil))
        }
        if !events.isEmpty {
            try await builder.addWorkoutEvents(events)
        }

        var metadata: [String: Any] = [HKMetadataKeyIndoorWorkout: true]
        metadata.merge(syncMetadata(record.id, component: "workout")) { _, new in new }
        metadata[Self.archiveKey] = try metadataString(WorkoutHealthArchive(record))
        let elevation = record.metrics.elevationMeters
        if elevation > 0 {
            metadata[HKMetadataKeyElevationAscended] = HKQuantity(unit: .meter(), doubleValue: elevation)
        }
        if let name = record.programName {
            metadata[HKMetadataKeyWorkoutBrandName] = name
        }
        if let summary = record.healthSummary {
            let totals: [HKQuantitySample] = [
                HKQuantitySample(type: HKQuantityType(.distanceWalkingRunning), quantity: HKQuantity(unit: .meter(), doubleValue: summary.distanceMeters), start: record.startDate, end: record.endDate),
                HKQuantitySample(type: HKQuantityType(.activeEnergyBurned), quantity: HKQuantity(unit: .kilocalorie(), doubleValue: summary.activeKcal), start: record.startDate, end: record.endDate)
            ]
            try await builder.addSamples(totals)
        }
        try await builder.addMetadata(metadata)

        try await builder.endCollection(at: record.endDate)
        _ = try await builder.finishWorkout()
    }

    struct RestorationResult {
        var records: [WorkoutRecord] = []
        var summaryOnlyCount = 0
        var skippedCount = 0
    }

    /// Only reads workouts written by this app. Empty results may also mean read access was denied.
    func restoreWorkouts() async throws -> RestorationResult {
        guard isAvailable else { throw HealthError.unavailable }
        try await requestAuthorization()
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    HKQuery.predicateForObjects(from: HKSource.default()),
                    HKQuery.predicateForObjects(withMetadataKey: "com.inai17ibar.TreadmillTracker.watchRecord")
                ]),
                HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyIndoorWorkout, allowedValues: [true])
            ]))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)])
        let workouts = try await descriptor.result(for: store)
        var result = RestorationResult()
        for workout in workouts where workout.workoutActivityType == .walking || workout.workoutActivityType == .running {
            try Task.checkCancellation()
            if workout.sourceRevision.source.bundleIdentifier == "com.inai17ibar.TreadmillTracker.watchkitapp",
               let encoded = workout.metadata?["com.inai17ibar.TreadmillTracker.watchRecord"] as? String,
               var record = try? WorkoutRecord.decodeList(Data(encoded.utf8)).first {
                record.savedToHealth = true
                result.records.append(record)
                continue
            }
            let archive: WorkoutHealthArchive? = decodeMetadata(workout.metadata?[Self.archiveKey])
            if let archive {
                let samples = try await HKSampleQueryDescriptor(
                    predicates: [.quantitySample(type: HKQuantityType(.distanceWalkingRunning),
                                                  predicate: HKQuery.predicateForObjects(from: workout))],
                    sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]).result(for: store)
                let segments: [WorkoutSegment] = samples.compactMap { decodeMetadata($0.metadata?[Self.segmentKey]) }
                if let record = try? archive.restoring(segments: segments) {
                    result.records.append(record)
                    continue
                }
            }
            // Never invent a historical weight, incline, or calorie calculation for old records.
            guard let distance = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                .sumQuantity()?.doubleValue(for: .meter()),
                  let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie()) else {
                result.skippedCount += 1
                continue
            }
            let syncID = workout.metadata?[HKMetadataKeySyncIdentifier] as? String
            let id = archive?.recordID ?? recordID(fromSyncIdentifier: syncID) ?? workout.uuid
            var record = WorkoutRecord(id: id, startDate: workout.startDate, endDate: workout.endDate,
                                       segments: [], weightKg: 0,
                                       programName: workout.metadata?[HKMetadataKeyWorkoutBrandName] as? String,
                                       savedToHealth: true)
            record.healthSummary = HealthWorkoutSummary(
                duration: workout.duration, distanceMeters: distance, activeKcal: energy,
                elevationMeters: (workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?.doubleValue(for: .meter()),
                gait: workout.workoutActivityType == .running ? .run : .walk)
            result.records.append(record)
            result.summaryOnlyCount += 1
        }
        return result
    }

    private func existingWorkout(for record: WorkoutRecord) async throws -> HKWorkout? {
        let syncID = "com.inai17ibar.TreadmillTracker.\(record.id.uuidString).workout"
        let matchesID = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [syncID])
        // Legacy workouts have no sync identifier; match exact timestamps within this app's source.
        let legacy = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K >= %@ AND %K <= %@ AND %K >= %@ AND %K <= %@",
                        HKSampleSortIdentifierStartDate, record.startDate.addingTimeInterval(-1) as NSDate,
                        HKSampleSortIdentifierStartDate, record.startDate.addingTimeInterval(1) as NSDate,
                        HKSampleSortIdentifierEndDate, record.endDate.addingTimeInterval(-1) as NSDate,
                        HKSampleSortIdentifierEndDate, record.endDate.addingTimeInterval(1) as NSDate),
            NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier))
        ])
        return try await HKSampleQueryDescriptor(predicates: [.workout(
            NSCompoundPredicate(andPredicateWithSubpredicates: [
                HKQuery.predicateForObjects(from: HKSource.default()),
                NSCompoundPredicate(orPredicateWithSubpredicates: [matchesID, legacy])
            ]))], sortDescriptors: [], limit: 1).result(for: store).first
    }

    private func recordID(fromSyncIdentifier value: String?) -> UUID? {
        let prefix = "com.inai17ibar.TreadmillTracker."
        guard let value, value.hasPrefix(prefix), value.hasSuffix(".workout") else { return nil }
        return UUID(uuidString: String(value.dropFirst(prefix.count).dropLast(".workout".count)))
    }

    private func metadataString<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
    }

    private func decodeMetadata<T: Decodable>(_ value: Any?) -> T? {
        guard let string = value as? String else { return nil }
        return try? JSONDecoder().decode(T.self, from: Data(string.utf8))
    }

    private func syncMetadata(_ id: UUID, component: String) -> [String: Any] {
        [HKMetadataKeySyncIdentifier: "com.inai17ibar.TreadmillTracker.\(id.uuidString).\(component)",
         HKMetadataKeySyncVersion: 1]
    }

    enum HealthError: LocalizedError {
        case unavailable
        case saveInProgress

        var errorDescription: String? {
            switch self {
            case .unavailable: return L10n.text("この端末ではヘルスケアを利用できません。")
            case .saveInProgress: return L10n.text("この記録はヘルスケアへ保存中です。")
            }
        }
    }
}
