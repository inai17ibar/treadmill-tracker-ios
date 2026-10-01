import Foundation

/// Optional target for a free workout.
public enum WorkoutGoal: Codable, Hashable, Sendable {
    case none
    case duration(TimeInterval)
    case distance(meters: Double)
    case activeKcal(Double)

    /// 0...1, or nil when there is no goal.
    public func progress(_ metrics: WorkoutMetrics) -> Double? {
        let ratio: Double
        switch self {
        case .none: return nil
        case .duration(let t): ratio = t > 0 ? metrics.activeDuration / t : 1
        case .distance(let m): ratio = m > 0 ? metrics.distanceMeters / m : 1
        case .activeKcal(let k): ratio = k > 0 ? metrics.activeKcal / k : 1
        }
        return min(1, max(0, ratio))
    }

    public func isReached(_ metrics: WorkoutMetrics) -> Bool { (progress(metrics) ?? 0) >= 1 }
}
