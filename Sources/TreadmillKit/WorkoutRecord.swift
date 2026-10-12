import Foundation

/// A finished workout as stored in the history.
public struct WorkoutRecord: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var startDate: Date
    public var endDate: Date
    public var segments: [WorkoutSegment]
    public var weightKg: Double
    public var programName: String?
    public var steps: Int?
    public var savedToHealth: Bool
    /// Factor applied to all segment speeds when the user corrected the distance to match the treadmill display.
    public var distanceCorrection: Double
    /// Older HealthKit workouts can only supply totals, not treadmill settings.
    public var healthSummary: HealthWorkoutSummary?

    public init(id: UUID = UUID(), startDate: Date, endDate: Date, segments: [WorkoutSegment], weightKg: Double,
                programName: String? = nil, steps: Int? = nil, savedToHealth: Bool = false, distanceCorrection: Double = 1) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.segments = segments
        self.weightKg = weightKg
        self.programName = programName
        self.steps = steps
        self.savedToHealth = savedToHealth
        self.distanceCorrection = distanceCorrection
    }

    public init?(session: WorkoutSession, programName: String? = nil, steps: Int? = nil) {
        guard session.state == .finished, let start = session.startDate, let end = session.endDate else { return nil }
        self.init(startDate: start, endDate: end, segments: session.segments, weightKg: session.weightKg,
                  programName: programName, steps: steps)
    }

    public var metrics: WorkoutMetrics {
        guard let summary = healthSummary else { return WorkoutMetrics(segments: segments, weightKg: weightKg) }
        var metrics = WorkoutMetrics(segments: [], weightKg: 0)
        metrics.activeDuration = summary.duration
        metrics.distanceMeters = summary.distanceMeters
        metrics.activeKcal = summary.activeKcal
        metrics.elevationMeters = summary.elevationMeters ?? 0
        return metrics
    }

    /// Gait with the most time; decides walking vs running for Apple Health.
    public var primaryGait: Gait {
        if let summary = healthSummary { return summary.gait }
        let run = segments.filter { $0.gait == .run }.reduce(0) { $0 + $1.duration }
        let walk = segments.filter { $0.gait == .walk }.reduce(0) { $0 + $1.duration }
        return run > walk ? .run : .walk
    }

    public var maxSpeedKmh: Double { segments.map(\.speedKmh).max() ?? 0 }
    public var maxInclinePercent: Double { segments.map(\.inclinePercent).max() ?? 0 }

    public var title: String {
        programName.map { L10n.text($0) } ?? (primaryGait == .run ? L10n.text("ランニング") : L10n.text("ウォーキング"))
    }

    public func splits(unitMeters: Double) -> [Split] { Splits.compute(segments, unitMeters: unitMeters) }

    /// Rescales all speeds so the total distance equals `meters` (e.g. the value shown on the treadmill).
    /// Calories are recomputed from the corrected speeds.
    public func correctingDistance(to meters: Double) -> WorkoutRecord {
        guard healthSummary == nil else { return self }
        let current = metrics.distanceMeters
        guard meters > 0, current > 0 else { return self }
        let factor = meters / current
        var copy = self
        copy.segments = segments.map { seg in
            var s = seg
            s.speedKmh *= factor
            return s
        }
        copy.distanceCorrection = distanceCorrection * factor
        return copy
    }
}

/// Exact HealthKit totals for records whose original treadmill segments are unavailable.
public struct HealthWorkoutSummary: Codable, Hashable, Sendable {
    public var duration: TimeInterval
    public var distanceMeters: Double
    public var activeKcal: Double
    public var elevationMeters: Double?
    public var gait: Gait

    public init(duration: TimeInterval, distanceMeters: Double, activeKcal: Double,
                elevationMeters: Double?, gait: Gait) {
        self.duration = duration
        self.distanceMeters = distanceMeters
        self.activeKcal = activeKcal
        self.elevationMeters = elevationMeters
        self.gait = gait
    }
}

/// Small workout metadata header. Segments are stored on their distance samples in HealthKit.
public struct WorkoutHealthArchive: Codable, Sendable {
    private let version: Int
    private var header: WorkoutRecord
    private let segmentCount: Int

    public var recordID: UUID { header.id }

    public init(_ record: WorkoutRecord) {
        version = 1
        segmentCount = record.segments.filter { $0.duration > 0 }.count
        header = record
        header.segments = []
        header.savedToHealth = true
    }

    public func restoring(segments: [WorkoutSegment]) throws -> WorkoutRecord {
        guard version == 1, header.healthSummary == nil, segments.count == segmentCount,
              header.weightKg.isFinite, header.weightKg > 0,
              header.distanceCorrection.isFinite, header.distanceCorrection > 0,
              segments.allSatisfy({ $0.duration > 0 && $0.start >= header.startDate && $0.end <= header.endDate
                  && $0.speedKmh.isFinite && $0.speedKmh >= 0 && $0.inclinePercent.isFinite }),
              zip(segments, segments.dropFirst()).allSatisfy({ $0.0.end <= $0.1.start }) else {
            throw ArchiveError.incomplete
        }
        var record = header
        record.segments = segments
        return record
    }

    public enum ArchiveError: Error { case incomplete }
}

extension WorkoutRecord {
    /// Preserve local details and IDs when merging HealthKit records, including old records with no app ID.
    public static func mergingHealthRecords(_ restored: [WorkoutRecord], into records: [WorkoutRecord])
        -> (records: [WorkoutRecord], added: Int) {
        var merged = records
        var added = 0
        for record in restored {
            if let index = merged.firstIndex(where: { $0.id == record.id ||
                (abs($0.startDate.timeIntervalSince(record.startDate)) < 1 &&
                 abs($0.endDate.timeIntervalSince(record.endDate)) < 1 &&
                 $0.primaryGait == record.primaryGait && $0.savedToHealth) }) {
                if merged[index].healthSummary != nil && record.healthSummary == nil {
                    merged[index] = record
                } else {
                    merged[index].savedToHealth = true
                }
            } else {
                merged.append(record)
                added += 1
            }
        }
        return (merged.sorted { $0.startDate > $1.startDate }, added)
    }

    public static func encodeList(_ records: [WorkoutRecord]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(records)
    }

    public static func decodeList(_ data: Data) throws -> [WorkoutRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([WorkoutRecord].self, from: data)
    }
}

/// Totals over a set of records.
public struct WorkoutTotals: Equatable, Sendable {
    public var count: Int
    public var activeDuration: TimeInterval
    public var distanceMeters: Double
    public var activeKcal: Double

    public init(_ records: [WorkoutRecord]) {
        let all = records.map(\.metrics)
        count = records.count
        activeDuration = all.reduce(0) { $0 + $1.activeDuration }
        distanceMeters = all.reduce(0) { $0 + $1.distanceMeters }
        activeKcal = all.reduce(0) { $0 + $1.activeKcal }
    }

    /// Totals for the calendar week (as defined by `calendar`) containing `date`.
    public static func week(of date: Date, records: [WorkoutRecord], calendar: Calendar = .current) -> WorkoutTotals {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return WorkoutTotals([]) }
        return WorkoutTotals(records.filter { interval.contains($0.startDate) })
    }
}
