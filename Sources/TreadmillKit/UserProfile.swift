import Foundation

public struct UserProfile: Codable, Equatable, Sendable {
    public var weightKg: Double
    public var heightCm: Double

    public init(weightKg: Double = 60, heightCm: Double = 170) {
        self.weightKg = weightKg
        self.heightCm = heightCm
    }

    /// Rough stride length used before steps have been measured.
    public func estimatedStrideMeters(gait: Gait) -> Double {
        heightCm / 100 * (gait == .walk ? 0.415 : 0.65)
    }
}

public enum StepMetrics {
    /// Average stride length (m) from distance and step count.
    public static func strideMeters(distanceMeters: Double, steps: Int) -> Double? {
        guard steps > 0, distanceMeters > 0 else { return nil }
        return distanceMeters / Double(steps)
    }

    /// Steps per minute.
    public static func cadence(steps: Int, duration: TimeInterval) -> Double? {
        guard steps > 0, duration > 0 else { return nil }
        return Double(steps) / duration * 60
    }
}
