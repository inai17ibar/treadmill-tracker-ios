import Foundation

/// A stretch of time at constant belt speed, incline and gait.
public struct WorkoutSegment: Codable, Equatable, Hashable, Sendable {
    public var start: Date
    public var end: Date
    public var speedKmh: Double
    public var inclinePercent: Double
    public var gait: Gait

    public init(start: Date, end: Date, speedKmh: Double, inclinePercent: Double, gait: Gait) {
        self.start = start
        self.end = end
        self.speedKmh = speedKmh
        self.inclinePercent = inclinePercent
        self.gait = gait
    }

    public var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
    public var distanceMeters: Double { speedKmh * 1000 / 3600 * duration }
    /// Vertical climb; the incline is rise over run, so this uses the horizontal component of the belt distance.
    public var elevationMeters: Double {
        guard inclinePercent > 0 else { return 0 }
        let g = inclinePercent / 100
        return distanceMeters * g / (1 + g * g).squareRoot()
    }

    public func rate(weightKg: Double) -> Metabolic.Rate {
        Metabolic.rate(speedKmh: speedKmh, inclinePercent: inclinePercent, gait: gait, weightKg: weightKg)
    }

    public func grossKcal(weightKg: Double) -> Double { rate(weightKg: weightKg).grossKcalPerMinute * duration / 60 }
    public func activeKcal(weightKg: Double) -> Double { rate(weightKg: weightKg).activeKcalPerMinute * duration / 60 }
}

/// Aggregate values over a list of segments.
public struct WorkoutMetrics: Equatable, Sendable {
    public var activeDuration: TimeInterval
    public var distanceMeters: Double
    public var grossKcal: Double
    public var activeKcal: Double
    public var elevationMeters: Double

    public init(segments: [WorkoutSegment], weightKg: Double) {
        activeDuration = segments.reduce(0) { $0 + $1.duration }
        distanceMeters = segments.reduce(0) { $0 + $1.distanceMeters }
        grossKcal = segments.reduce(0) { $0 + $1.grossKcal(weightKg: weightKg) }
        activeKcal = segments.reduce(0) { $0 + $1.activeKcal(weightKg: weightKg) }
        elevationMeters = segments.reduce(0) { $0 + $1.elevationMeters }
    }

    public var averageSpeedKmh: Double {
        activeDuration > 0 ? distanceMeters / activeDuration * 3.6 : 0
    }
}

/// Distance split (e.g. every 1 km) with the active time it took.
public struct Split: Equatable, Hashable, Sendable {
    public var index: Int
    public var distanceMeters: Double
    public var duration: TimeInterval

    public var averageSpeedKmh: Double { duration > 0 ? distanceMeters / duration * 3.6 : 0 }
}

public enum Splits {
    /// Splits of `unitMeters` each; the last one may be partial (omitted if shorter than 1 m).
    public static func compute(_ segments: [WorkoutSegment], unitMeters: Double) -> [Split] {
        guard unitMeters > 0 else { return [] }
        var splits: [Split] = []
        var dist = 0.0, time = 0.0
        for seg in segments where seg.duration > 0 {
            let mps = seg.speedKmh / 3.6
            var remaining = seg.duration
            guard mps > 0 else { time += remaining; continue }
            while remaining > 0 {
                let need = (unitMeters - dist) / mps
                if need <= remaining {
                    time += need
                    remaining -= need
                    splits.append(Split(index: splits.count + 1, distanceMeters: unitMeters, duration: time))
                    dist = 0
                    time = 0
                } else {
                    dist += mps * remaining
                    time += remaining
                    remaining = 0
                }
            }
        }
        if dist >= 1 {
            splits.append(Split(index: splits.count + 1, distanceMeters: dist, duration: time))
        }
        return splits
    }
}

/// Records a treadmill workout from the speed and incline the user sets on the machine.
/// Time is always passed in so the logic is deterministic and testable.
public struct WorkoutSession: Sendable {
    public enum State: String, Sendable {
        case ready
        case running
        case paused
        case finished
    }

    public private(set) var state: State = .ready
    public private(set) var startDate: Date?
    public private(set) var endDate: Date?
    public private(set) var speedKmh: Double
    public private(set) var inclinePercent: Double
    public private(set) var gaitMode: GaitMode
    public let weightKg: Double
    /// Closed segments, oldest first.
    public private(set) var segments: [WorkoutSegment] = []
    private var openSince: Date?

    public init(speedKmh: Double, inclinePercent: Double, gaitMode: GaitMode = .auto, weightKg: Double) {
        self.speedKmh = TreadmillLimits.clampSpeed(speedKmh)
        self.inclinePercent = TreadmillLimits.clampIncline(inclinePercent)
        self.gaitMode = gaitMode
        self.weightKg = weightKg
    }

    public var gait: Gait { gaitMode.resolve(speedKmh: speedKmh) }

    public mutating func start(at date: Date) {
        guard state == .ready else { return }
        state = .running
        startDate = date
        openSince = date
    }

    public mutating func pause(at date: Date) {
        guard state == .running else { return }
        closeSegment(at: date)
        state = .paused
    }

    public mutating func resume(at date: Date) {
        guard state == .paused else { return }
        state = .running
        openSince = date
    }

    public mutating func finish(at date: Date) {
        guard state == .running || state == .paused else { return }
        closeSegment(at: date)
        state = .finished
        endDate = date
    }

    public mutating func setSpeed(_ kmh: Double, at date: Date) {
        let value = TreadmillLimits.clampSpeed(kmh)
        guard value != speedKmh else { return }
        split(at: date) { $0.speedKmh = value }
    }

    public mutating func setIncline(_ percent: Double, at date: Date) {
        let value = TreadmillLimits.clampIncline(percent)
        guard value != inclinePercent else { return }
        split(at: date) { $0.inclinePercent = value }
    }

    public mutating func setGaitMode(_ mode: GaitMode, at date: Date) {
        guard mode != gaitMode else { return }
        split(at: date) { $0.gaitMode = mode }
    }

    /// Closed segments plus the in-progress one up to `date`.
    public func segments(through date: Date) -> [WorkoutSegment] {
        guard let openSince, state == .running, date > openSince else { return segments }
        return segments + [currentSegment(from: openSince, to: date)]
    }

    public func metrics(at date: Date) -> WorkoutMetrics {
        WorkoutMetrics(segments: segments(through: date), weightKg: weightKg)
    }

    public var currentRate: Metabolic.Rate {
        Metabolic.rate(speedKmh: speedKmh, inclinePercent: inclinePercent, gait: gait, weightKg: weightKg)
    }

    private mutating func split(at date: Date, change: (inout WorkoutSession) -> Void) {
        let running = state == .running
        if running { closeSegment(at: date) }
        change(&self)
        if running { openSince = date }
    }

    private mutating func closeSegment(at date: Date) {
        guard let start = openSince else { return }
        openSince = nil
        guard date > start else { return }
        let seg = currentSegment(from: start, to: date)
        if let last = segments.last, last.end == seg.start, last.speedKmh == seg.speedKmh,
           last.inclinePercent == seg.inclinePercent, last.gait == seg.gait {
            segments[segments.count - 1].end = seg.end
        } else {
            segments.append(seg)
        }
    }

    private func currentSegment(from start: Date, to end: Date) -> WorkoutSegment {
        WorkoutSegment(start: start, end: end, speedKmh: speedKmh, inclinePercent: inclinePercent, gait: gait)
    }
}
