import Foundation

public enum UnitSystem: String, Codable, CaseIterable, Sendable {
    case metric
    case imperial

    public static let metersPerMile = 1609.344

    public var displayName: String {
        switch self {
        case .metric: return "km・km/h"
        case .imperial: return "mile・mph"
        }
    }

    public var speedLabel: String { self == .metric ? "km/h" : "mph" }
    public var distanceLabel: String { self == .metric ? "km" : "mi" }
    public var paceLabel: String { self == .metric ? "/km" : "/mi" }

    /// Meters per displayed distance unit.
    public var unitMeters: Double { self == .metric ? 1000 : Self.metersPerMile }

    public func speed(fromKmh kmh: Double) -> Double { kmh * 1000 / unitMeters }
    public func kmh(fromSpeed value: Double) -> Double { value * unitMeters / 1000 }
    public func distance(fromMeters m: Double) -> Double { m / unitMeters }
    public func meters(fromDistance value: Double) -> Double { value * unitMeters }

    /// Seconds per displayed distance unit, or nil when not moving.
    public func pace(speedKmh: Double) -> Double? {
        guard speedKmh > 0 else { return nil }
        return unitMeters / (speedKmh * 1000 / 3600)
    }

    public func speedText(kmh: Double) -> String { String(format: "%.1f", speed(fromKmh: kmh)) }
    public func distanceText(meters: Double) -> String { String(format: "%.2f", distance(fromMeters: meters)) }
    public func paceText(speedKmh: Double) -> String {
        pace(speedKmh: speedKmh).map(Format.pace) ?? "--'--\""
    }
}

public enum Format {
    /// "5:07" or "1:02:03".
    public static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// "6'15\"" (minutes'seconds").
    public static func pace(_ secondsPerUnit: Double) -> String {
        let total = Int(secondsPerUnit.rounded())
        return String(format: "%d'%02d\"", total / 60, total % 60)
    }

    public static func kcal(_ value: Double) -> String { String(format: "%.0f", value) }
    public static func percent(_ value: Double) -> String { String(format: "%.1f", value) }
}

/// Settings ranges of typical gym treadmills.
public enum TreadmillLimits {
    public static let speedKmh: ClosedRange<Double> = 0.5...25
    public static let inclinePercent: ClosedRange<Double> = -3...40

    public static func clampSpeed(_ kmh: Double) -> Double {
        (min(max(kmh, speedKmh.lowerBound), speedKmh.upperBound) * 100).rounded() / 100
    }

    public static func clampIncline(_ percent: Double) -> Double {
        (min(max(percent, inclinePercent.lowerBound), inclinePercent.upperBound) * 10).rounded() / 10
    }
}
