import Foundation

public struct ProgramStep: Codable, Hashable, Sendable {
    public var label: String
    public var duration: TimeInterval
    public var speedKmh: Double
    public var inclinePercent: Double

    public init(_ label: String, minutes: Double, speedKmh: Double, inclinePercent: Double = 0) {
        self.label = label
        self.duration = minutes * 60
        self.speedKmh = speedKmh
        self.inclinePercent = inclinePercent
    }
}

/// A timed sequence of speed / incline settings (warm-up, intervals, hill walks...).
public struct WorkoutProgram: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var summary: String
    public var steps: [ProgramStep]

    public init(id: String, name: String, summary: String, steps: [ProgramStep]) {
        self.id = id
        self.name = name
        self.summary = summary
        self.steps = steps
    }

    public var totalDuration: TimeInterval { steps.reduce(0) { $0 + $1.duration } }
    public var totalDistanceMeters: Double { steps.reduce(0) { $0 + $1.speedKmh / 3.6 * $1.duration } }

    public func estimatedActiveKcal(weightKg: Double, gaitMode: GaitMode = .auto) -> Double {
        steps.reduce(0) { sum, step in
            let gait = gaitMode.resolve(speedKmh: step.speedKmh)
            let rate = Metabolic.rate(speedKmh: step.speedKmh, inclinePercent: step.inclinePercent, gait: gait, weightKg: weightKg)
            return sum + rate.activeKcalPerMinute * step.duration / 60
        }
    }

    /// Where the program is after `elapsed` seconds of active time.
    public func position(atElapsed elapsed: TimeInterval) -> ProgramPosition {
        var t = 0.0
        for (i, step) in steps.enumerated() {
            if elapsed < t + step.duration {
                return ProgramPosition(stepIndex: i, step: step, elapsedInStep: elapsed - t,
                                       next: i + 1 < steps.count ? steps[i + 1] : nil, isComplete: false)
            }
            t += step.duration
        }
        return ProgramPosition(stepIndex: max(0, steps.count - 1), step: steps.last, elapsedInStep: steps.last?.duration ?? 0,
                               next: nil, isComplete: true)
    }

    /// Program with every step's speed scaled (e.g. 0.9 = 10% easier).
    public func scaledSpeed(by factor: Double) -> WorkoutProgram {
        var copy = self
        copy.steps = steps.map { step in
            var s = step
            s.speedKmh = TreadmillLimits.clampSpeed((step.speedKmh * factor * 10).rounded() / 10)
            return s
        }
        return copy
    }
}

public struct ProgramPosition: Equatable, Sendable {
    public var stepIndex: Int
    public var step: ProgramStep?
    public var elapsedInStep: TimeInterval
    public var next: ProgramStep?
    public var isComplete: Bool

    public var remainingInStep: TimeInterval { max(0, (step?.duration ?? 0) - elapsedInStep) }
    public var stepProgress: Double {
        guard let d = step?.duration, d > 0 else { return 1 }
        return min(1, elapsedInStep / d)
    }
}

extension WorkoutProgram {
    private static func repeated(_ count: Int, _ steps: [ProgramStep]) -> [ProgramStep] {
        (0..<count).flatMap { _ in steps }
    }

    public static let presets: [WorkoutProgram] = [
        WorkoutProgram(
            id: "12-3-30", name: "12-3-30 ウォーク",
            summary: "傾斜 12%・時速 4.8 km（3 mph）で 30 分歩く定番の坂道ウォーキング",
            steps: [ProgramStep("坂道ウォーク", minutes: 30, speedKmh: 4.8, inclinePercent: 12)]),
        WorkoutProgram(
            id: "fat-burn-walk", name: "脂肪燃焼ウォーク",
            summary: "やや速歩き＋緩い傾斜で 30 分。会話できる強度を保つ",
            steps: [
                ProgramStep("ウォームアップ", minutes: 5, speedKmh: 4.5, inclinePercent: 1),
                ProgramStep("速歩き", minutes: 20, speedKmh: 5.8, inclinePercent: 5),
                ProgramStep("クールダウン", minutes: 5, speedKmh: 4.5, inclinePercent: 0)
            ]),
        WorkoutProgram(
            id: "hill-intervals", name: "坂道インターバル",
            summary: "傾斜 10% と 2% を 2 分ずつ 6 セット",
            steps: [ProgramStep("ウォームアップ", minutes: 5, speedKmh: 5.0, inclinePercent: 1)]
                + repeated(6, [
                    ProgramStep("上り", minutes: 2, speedKmh: 5.5, inclinePercent: 10),
                    ProgramStep("平坦", minutes: 2, speedKmh: 5.0, inclinePercent: 2)
                ])
                + [ProgramStep("クールダウン", minutes: 3, speedKmh: 4.5, inclinePercent: 0)]),
        WorkoutProgram(
            id: "walk-jog", name: "ウォーク＆ジョグ",
            summary: "ランニング入門。2 分ジョグ＋2 分ウォークを 6 セット",
            steps: [ProgramStep("ウォームアップ", minutes: 5, speedKmh: 5.0, inclinePercent: 1)]
                + repeated(6, [
                    ProgramStep("ジョグ", minutes: 2, speedKmh: 7.5, inclinePercent: 1),
                    ProgramStep("ウォーク", minutes: 2, speedKmh: 5.5, inclinePercent: 1)
                ])
                + [ProgramStep("クールダウン", minutes: 5, speedKmh: 4.5, inclinePercent: 0)]),
        WorkoutProgram(
            id: "run-intervals", name: "ランニング インターバル",
            summary: "1 分速く走る＋2 分歩くを 8 セット。心肺を強化",
            steps: [ProgramStep("ウォームアップ", minutes: 5, speedKmh: 6.0, inclinePercent: 1)]
                + repeated(8, [
                    ProgramStep("ダッシュ", minutes: 1, speedKmh: 11.0, inclinePercent: 1),
                    ProgramStep("リカバリー", minutes: 2, speedKmh: 5.5, inclinePercent: 1)
                ])
                + [ProgramStep("クールダウン", minutes: 5, speedKmh: 5.0, inclinePercent: 0)]),
        WorkoutProgram(
            id: "steady-run", name: "30 分ジョグ",
            summary: "一定ペースで 20 分走る。傾斜 1% で屋外ランに近い負荷",
            steps: [
                ProgramStep("ウォームアップ", minutes: 5, speedKmh: 6.0, inclinePercent: 1),
                ProgramStep("ジョグ", minutes: 20, speedKmh: 8.5, inclinePercent: 1),
                ProgramStep("クールダウン", minutes: 5, speedKmh: 5.0, inclinePercent: 0)
            ])
    ]
}
