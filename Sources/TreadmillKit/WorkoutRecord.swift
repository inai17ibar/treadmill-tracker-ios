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

    public var metrics: WorkoutMetrics { WorkoutMetrics(segments: segments, weightKg: weightKg) }

    /// Gait with the most time; decides walking vs running for Apple Health.
    public var primaryGait: Gait {
        let run = segments.filter { $0.gait == .run }.reduce(0) { $0 + $1.duration }
        let walk = segments.filter { $0.gait == .walk }.reduce(0) { $0 + $1.duration }
        return run > walk ? .run : .walk
    }

    public var maxSpeedKmh: Double { segments.map(\.speedKmh).max() ?? 0 }
    public var maxInclinePercent: Double { segments.map(\.inclinePercent).max() ?? 0 }

    public var title: String {
        programName ?? (primaryGait == .run ? "ランニング" : "ウォーキング")
    }

    public func splits(unitMeters: Double) -> [Split] { Splits.compute(segments, unitMeters: unitMeters) }

    /// Rescales all speeds so the total distance equals `meters` (e.g. the value shown on the treadmill).
    /// Calories are recomputed from the corrected speeds.
    public func correctingDistance(to meters: Double) -> WorkoutRecord {
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

extension WorkoutRecord {
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
