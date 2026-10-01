import Foundation
import Observation
import TreadmillKit
import UIKit

/// Drives a live treadmill workout: the session clock, program steps, pedometer and voice prompts.
@MainActor
@Observable
final class WorkoutModel {
    private(set) var session: WorkoutSession
    let program: WorkoutProgram?
    let goal: WorkoutGoal
    let units: UnitSystem
    private(set) var now = Date()
    private(set) var steps = 0
    private(set) var cadence: Double?
    private(set) var finishedRecord: WorkoutRecord?

    private let coach: VoiceCoach
    private let pedometer = PedometerService()
    private let haptics = UINotificationFeedbackGenerator()
    private var tickTask: Task<Void, Never>?
    private var lastStepIndex: Int?
    private var programCompleted = false
    private var announcedNextFor: Int?
    private var announcedUnits = 0
    private var goalAnnounced = false

    init(setup: WorkoutSetup, weightKg: Double, units: UnitSystem, voiceEnabled: Bool) {
        let first = setup.program?.steps.first
        session = WorkoutSession(speedKmh: first?.speedKmh ?? setup.speedKmh,
                                 inclinePercent: first?.inclinePercent ?? setup.inclinePercent,
                                 gaitMode: setup.gaitMode, weightKg: weightKg)
        program = setup.program
        goal = setup.program == nil ? setup.goal : .none
        self.units = units
        coach = VoiceCoach(isEnabled: voiceEnabled)
    }

    var metrics: WorkoutMetrics { session.metrics(at: now) }
    var programPosition: ProgramPosition? { program?.position(atElapsed: metrics.activeDuration) }
    var goalProgress: Double? { goal.progress(metrics) }
    var isRunning: Bool { session.state == .running }

    var voiceEnabled: Bool {
        get { coach.isEnabled }
        set { coach.isEnabled = newValue }
    }

    func start() {
        guard session.state == .ready else { return }
        let date = Date()
        session.start(at: date)
        now = date
        UIApplication.shared.isIdleTimerDisabled = true
        pedometer.start(from: date) { [weak self] steps, cadence in
            self?.steps = steps
            self?.cadence = cadence
        }
        if let step = program?.steps.first {
            lastStepIndex = 0
            coach.say("\(program?.name ?? "")を始めます。\(instruction(for: step))")
        } else {
            coach.say("ワークアウトを始めます。速度 \(speedPhrase(session.speedKmh))")
        }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self else { return }
                self.tick()
            }
        }
    }

    func togglePause() {
        let date = Date()
        switch session.state {
        case .running:
            session.pause(at: date)
            coach.say("一時停止")
        case .paused:
            session.resume(at: date)
            coach.say("再開します")
        default:
            break
        }
        now = date
    }

    /// `delta` is in the displayed unit (km/h or mph).
    func changeSpeed(by delta: Double) {
        let displayed = units.speed(fromKmh: session.speedKmh) + delta
        setSpeed(kmh: units.kmh(fromSpeed: (displayed * 10).rounded() / 10))
    }

    func setSpeed(kmh: Double) {
        let date = Date()
        session.setSpeed(kmh, at: date)
        now = date
    }

    func changeIncline(by delta: Double) {
        let date = Date()
        session.setIncline(((session.inclinePercent + delta) * 2).rounded() / 2, at: date)
        now = date
    }

    func setGaitMode(_ mode: GaitMode) {
        let date = Date()
        session.setGaitMode(mode, at: date)
        now = date
    }

    func finish() {
        let date = Date()
        session.finish(at: date)
        now = date
        tickTask?.cancel()
        pedometer.stop()
        coach.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        finishedRecord = WorkoutRecord(session: session, programName: program?.name, steps: steps > 0 ? steps : nil)
    }

    /// Stops everything without producing a record (e.g. the view was dismissed).
    func cancel() {
        tickTask?.cancel()
        pedometer.stop()
        coach.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func tick() {
        guard session.state == .running else { return }
        now = Date()
        let m = metrics

        if let program, !programCompleted {
            let pos = program.position(atElapsed: m.activeDuration)
            if pos.isComplete {
                programCompleted = true
                haptics.notificationOccurred(.success)
                coach.say("\(program.name)が完了しました。お疲れさまでした。")
            } else if pos.stepIndex != lastStepIndex, let step = pos.step {
                lastStepIndex = pos.stepIndex
                let date = Date()
                session.setSpeed(step.speedKmh, at: date)
                session.setIncline(step.inclinePercent, at: date)
                haptics.notificationOccurred(.warning)
                coach.say("\(step.label)。\(instruction(for: step))")
            } else if let next = pos.next, pos.remainingInStep <= 10, (pos.step?.duration ?? 0) > 20,
                      announcedNextFor != pos.stepIndex {
                announcedNextFor = pos.stepIndex
                coach.say("10 秒後に\(next.label)")
            }
        }

        let unitsDone = Int(units.distance(fromMeters: m.distanceMeters))
        if unitsDone > announcedUnits {
            announcedUnits = unitsDone
            coach.say("\(unitsDone) \(units == .metric ? "キロ" : "マイル")。\(Self.spokenDuration(m.activeDuration))")
        }

        if !goalAnnounced, goal.isReached(m) {
            goalAnnounced = true
            haptics.notificationOccurred(.success)
            coach.say("目標を達成しました！")
        }
    }

    private static func spokenDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return (h > 0 ? "\(h)時間" : "") + "\(m)分\(s)秒"
    }

    private func speedPhrase(_ kmh: Double) -> String {
        "\(units.speedText(kmh: kmh)) \(units == .metric ? "キロ" : "マイル")"
    }

    private func instruction(for step: ProgramStep) -> String {
        "速度を\(speedPhrase(step.speedKmh))、傾斜を\(Format.percent(step.inclinePercent))パーセントにしてください"
    }
}
