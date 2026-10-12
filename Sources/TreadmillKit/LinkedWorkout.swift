import Foundation

public struct LinkedWorkout: Codable, Equatable, Sendable {
    public enum State: String, Codable, Sendable { case running, paused, finished, cancelled }
    public var id: UUID
    public var start: Date
    public var updated: Date
    public var state: State
    public var running: Bool
    public init(id: UUID, start: Date, updated: Date = Date(), state: State, running: Bool) {
        self.id = id; self.start = start; self.updated = updated; self.state = state; self.running = running
    }
    public func canReplace(_ previous: LinkedWorkout?, now: Date) -> Bool {
        guard updated.timeIntervalSince(now) <= 30 else { return false }
        if state == .running || state == .paused { guard now.timeIntervalSince(updated) < 90 else { return false } }
        guard let previous else { return true }
        guard updated > previous.updated else { return false }
        if previous.id == id && (previous.state == .finished || previous.state == .cancelled) { return false }
        return true
    }
}
