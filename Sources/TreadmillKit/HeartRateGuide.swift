import Foundation

public struct HeartRateSettings: Codable, Equatable, Sendable {
    public var configured = false
    public var lower: Double = 100
    public var upper: Double = 140
    public var haptics = true
    public var saveToHealth = true
    public init() {}
    public var isValid: Bool { lower.isFinite && upper.isFinite && lower >= 40 && upper <= 220 && upper - lower >= 5 }
    public static let storageKey = "watchHeartRateSettings"
}

public struct HeartRatePoint: Codable, Hashable, Sendable {
    public var date: Date
    public var bpm: Double
    public init(date: Date, bpm: Double) { self.date = date; self.bpm = bpm }
}

/// Pure, timestamp-based logic; stale measurements never produce coaching.
public struct HeartRateGuide {
    public enum Zone: String { case waiting, warmup, low, target, high, paused }
    public private(set) var points: [HeartRatePoint] = []
    public private(set) var zone: Zone = .waiting
    private var candidate: Zone = .waiting
    private var candidateSince: Date?
    private var lastAlert: Date?
    public init() {}
    public mutating func ingest(_ point: HeartRatePoint, now: Date) {
        guard point.bpm.isFinite, (30...250).contains(point.bpm), abs(point.date.timeIntervalSince(now)) <= 20,
              points.last.map({ point.date > $0.date }) ?? true else { return }
        points.append(point)
        points.removeAll { now.timeIntervalSince($0.date) > 15 }
    }
    public mutating func evaluate(now: Date, activeSeconds: Double, paused: Bool, settings: HeartRateSettings) -> (Zone, Bool) {
        guard !paused else { zone = .paused; candidateSince = nil; return (zone, false) }
        guard settings.isValid, let latest = points.last, now.timeIntervalSince(latest.date) <= 20 else {
            zone = .waiting; candidateSince = nil; return (zone, false)
        }
        guard activeSeconds >= 120 else { zone = .warmup; candidateSince = nil; return (zone, false) }
        let recent = points.filter { now.timeIntervalSince($0.date) <= 15 }
        guard !recent.isEmpty else { zone = .waiting; candidateSince = nil; return (zone, false) }
        let bpm = recent.map(\.bpm).reduce(0,+) / Double(recent.count)
        // 3 bpm hysteresis keeps the display stable near either boundary.
        let next: Zone
        if zone == .low && bpm < settings.lower + 3 { next = .low }
        else if zone == .high && bpm > settings.upper - 3 { next = .high }
        else { next = bpm < settings.lower ? .low : bpm > settings.upper ? .high : .target }
        if next != candidate || candidateSince == nil { candidate = next; candidateSince = now }
        guard now.timeIntervalSince(candidateSince!) >= 15 else { return (zone, false) }
        zone = next
        let alert = (next == .low || next == .high) && (lastAlert.map { now.timeIntervalSince($0) >= 60 } ?? true)
        if alert { lastAlert = now }
        return (zone, alert && settings.haptics)
    }
}
