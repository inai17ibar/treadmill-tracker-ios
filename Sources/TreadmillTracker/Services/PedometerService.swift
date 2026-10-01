import CoreMotion
import Foundation

/// Step count and cadence from the iPhone's motion coprocessor (works in a pocket or armband; not on the treadmill console).
final class PedometerService {
    private let pedometer = CMPedometer()

    static var isAvailable: Bool { CMPedometer.isStepCountingAvailable() }

    /// `handler` is called on the main queue with total steps since `start` and current cadence in steps/min.
    func start(from start: Date, handler: @escaping @MainActor (Int, Double?) -> Void) {
        guard Self.isAvailable else { return }
        pedometer.startUpdates(from: start) { data, _ in
            guard let data else { return }
            let steps = data.numberOfSteps.intValue
            let cadence = data.currentCadence.map { $0.doubleValue * 60 }
            Task { @MainActor in handler(steps, cadence) }
        }
    }

    func stop() {
        pedometer.stopUpdates()
    }
}
