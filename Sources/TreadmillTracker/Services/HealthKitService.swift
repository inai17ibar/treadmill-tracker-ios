import Foundation
import HealthKit
import TreadmillKit

/// Saves treadmill workouts to Apple Health (indoor walking / running) and reads the user's weight and height.
@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKQuantityType(.distanceWalkingRunning), HKQuantityType(.activeEnergyBurned)]
    }

    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.bodyMass), HKQuantityType(.height)]
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
        guard isAvailable else { throw HealthError.unavailable }
        try await requestAuthorization()

        let config = HKWorkoutConfiguration()
        config.activityType = record.primaryGait == .run ? .running : .walking
        config.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: record.startDate)

        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let energyType = HKQuantityType(.activeEnergyBurned)
        var samples: [HKSample] = []
        for seg in record.segments where seg.duration > 0 {
            samples.append(HKQuantitySample(type: distanceType,
                                            quantity: HKQuantity(unit: .meter(), doubleValue: seg.distanceMeters),
                                            start: seg.start, end: seg.end))
            samples.append(HKQuantitySample(type: energyType,
                                            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: seg.activeKcal(weightKg: record.weightKg)),
                                            start: seg.start, end: seg.end))
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
        let elevation = record.metrics.elevationMeters
        if elevation > 0 {
            metadata[HKMetadataKeyElevationAscended] = HKQuantity(unit: .meter(), doubleValue: elevation)
        }
        if let name = record.programName {
            metadata[HKMetadataKeyWorkoutBrandName] = name
        }
        try await builder.addMetadata(metadata)

        try await builder.endCollection(at: record.endDate)
        _ = try await builder.finishWorkout()
    }

    enum HealthError: LocalizedError {
        case unavailable

        var errorDescription: String? { "この端末ではヘルスケアを利用できません。" }
    }
}
