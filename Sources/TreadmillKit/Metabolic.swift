import Foundation

/// How the user moves on the belt. Walking and running use different ACSM equations.
public enum Gait: String, Codable, CaseIterable, Sendable {
    case walk
    case run

    public var displayName: String {
        switch self {
        case .walk: return "ウォーキング"
        case .run: return "ランニング"
        }
    }
}

/// The user's choice; `.auto` picks walking or running from the belt speed.
public enum GaitMode: String, Codable, CaseIterable, Sendable {
    case auto
    case walk
    case run

    public var displayName: String {
        switch self {
        case .auto: return "自動"
        case .walk: return "歩く"
        case .run: return "走る"
        }
    }

    public func resolve(speedKmh: Double) -> Gait {
        switch self {
        case .walk: return .walk
        case .run: return .run
        case .auto: return speedKmh >= Metabolic.autoRunThresholdKmh ? .run : .walk
        }
    }
}

/// Energy expenditure on a treadmill from the ACSM metabolic equations.
///
/// Walking: VO2 = 0.1·S + 1.8·S·G + 3.5
/// Running: VO2 = 0.2·S + 0.9·S·G + 3.5
/// (VO2 in mL/kg/min, S = speed in m/min, G = grade as a fraction). 1 L of O2 ≈ 5 kcal.
public enum Metabolic {
    public static let restingVO2 = 3.5
    public static let kcalPerLiterO2 = 5.0
    /// Speed at which `.auto` switches from walking to running.
    public static let autoRunThresholdKmh = 7.5

    public struct Rate: Equatable, Sendable {
        /// Total energy including resting metabolism (kcal/min).
        public var grossKcalPerMinute: Double
        /// Energy above resting metabolism, comparable to Apple Health "active energy" (kcal/min).
        public var activeKcalPerMinute: Double
        public var mets: Double
    }

    /// Oxygen consumption in mL/kg/min. Declines are treated as level ground (the equations are not valid for negative grades).
    public static func vo2(speedKmh: Double, inclinePercent: Double, gait: Gait) -> Double {
        let s = max(0, speedKmh) * 1000 / 60
        let g = max(0, inclinePercent) / 100
        guard s > 0 else { return restingVO2 }
        switch gait {
        case .walk: return 0.1 * s + 1.8 * s * g + restingVO2
        case .run: return 0.2 * s + 0.9 * s * g + restingVO2
        }
    }

    public static func rate(speedKmh: Double, inclinePercent: Double, gait: Gait, weightKg: Double) -> Rate {
        let v = vo2(speedKmh: speedKmh, inclinePercent: inclinePercent, gait: gait)
        let perMlKg = max(0, weightKg) / 1000 * kcalPerLiterO2
        return Rate(grossKcalPerMinute: v * perMlKg,
                    activeKcalPerMinute: max(0, v - restingVO2) * perMlKg,
                    mets: v / restingVO2)
    }
}
