import SwiftUI
import TreadmillKit

private struct ActiveWorkout: Identifiable {
    let id = UUID()
    let model: WorkoutModel
}

struct HomeView: View {
    @AppStorage(SettingsKey.weightKg) private var weightKg = 60.0
    @AppStorage(SettingsKey.units) private var units: UnitSystem = .metric
    @AppStorage(SettingsKey.voiceEnabled) private var voiceEnabled = true
    @AppStorage(SettingsKey.startSpeedKmh) private var speedKmh = 5.0
    @AppStorage(SettingsKey.startInclinePercent) private var inclinePercent = 1.0
    @AppStorage(SettingsKey.gaitMode) private var gaitMode: GaitMode = .auto

    @State private var programID = ""
    @State private var intensity = 1.0
    @State private var goalKind: GoalKind = .none
    @State private var goalMinutes = 30.0
    @State private var goalDistance = 3.0
    @State private var goalKcal = 200.0
    @State private var active: ActiveWorkout?

    private var program: WorkoutProgram? {
        WorkoutProgram.presets.first { $0.id == programID }.map { $0.scaledSpeed(by: intensity) }
    }

    private var goal: WorkoutGoal {
        switch goalKind {
        case .none: return .none
        case .duration: return .duration(goalMinutes * 60)
        case .distance: return .distance(meters: units.meters(fromDistance: goalDistance))
        case .kcal: return .activeKcal(goalKcal)
        }
    }

    private var displayedSpeed: Binding<Double> {
        Binding(get: { (units.speed(fromKmh: speedKmh) * 10).rounded() / 10 },
                set: { speedKmh = TreadmillLimits.clampSpeed(units.kmh(fromSpeed: $0)) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("メニュー") {
                    Picker("メニュー", selection: $programID) {
                        VStack(alignment: .leading) {
                            Text("フリー")
                            Text("速度と傾斜を自由に変えて記録").font(.caption).foregroundStyle(.secondary)
                        }
                        .tag("")
                        ForEach(WorkoutProgram.presets) { p in
                            VStack(alignment: .leading) {
                                Text(p.name)
                                Text(p.summary).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(p.id)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if let program {
                    programSection(program)
                } else {
                    freeSections
                }

                Section {
                    Picker("歩く / 走る", selection: $gaitMode) {
                        ForEach(GaitMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("歩く / 走る")
                } footer: {
                    Text("カロリーの計算式を切り替えます。自動は時速 \(Format.percent(Metabolic.autoRunThresholdKmh)) km 以上を「走る」とします。")
                }

                Section {
                    Button {
                        let setup = WorkoutSetup(program: program, speedKmh: speedKmh, inclinePercent: inclinePercent,
                                                 gaitMode: gaitMode, goal: goal)
                        active = ActiveWorkout(model: WorkoutModel(setup: setup, weightKg: weightKg, units: units,
                                                                   voiceEnabled: voiceEnabled))
                    } label: {
                        Label("スタート", systemImage: "play.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("トレッドミル")
        }
        .fullScreenCover(item: $active) { workout in
            WorkoutFlowView(model: workout.model) { active = nil }
        }
    }

    @ViewBuilder
    private func programSection(_ program: WorkoutProgram) -> some View {
        Section("内容") {
            LabeledContent("時間", value: Format.duration(program.totalDuration))
            LabeledContent("距離の目安", value: "\(units.distanceText(meters: program.totalDistanceMeters)) \(units.distanceLabel)")
            LabeledContent("消費カロリーの目安",
                           value: "\(Format.kcal(program.estimatedActiveKcal(weightKg: weightKg, gaitMode: gaitMode))) kcal")
            Stepper(value: $intensity, in: 0.7...1.3, step: 0.05) {
                LabeledContent("速度の強さ", value: "\(Int((intensity * 100).rounded()))%")
            }
            DisclosureGroup("ステップ（\(program.steps.count)）") {
                ForEach(Array(program.steps.enumerated()), id: \.offset) { _, step in
                    HStack {
                        Text(step.label)
                        Spacer()
                        Text("\(Format.duration(step.duration))・\(units.speedText(kmh: step.speedKmh)) \(units.speedLabel)・\(Format.percent(step.inclinePercent))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
        }
    }

    @ViewBuilder
    private var freeSections: some View {
        Section("スタート時の設定") {
            Stepper(value: displayedSpeed, in: units.speed(fromKmh: TreadmillLimits.speedKmh.lowerBound)...units.speed(fromKmh: TreadmillLimits.speedKmh.upperBound), step: 0.1) {
                LabeledContent("速度", value: "\(units.speedText(kmh: speedKmh)) \(units.speedLabel)")
            }
            Stepper(value: $inclinePercent, in: TreadmillLimits.inclinePercent, step: 0.5) {
                LabeledContent("傾斜", value: "\(Format.percent(inclinePercent))%")
            }
        }

        Section("目標") {
            Picker("目標", selection: $goalKind) {
                ForEach(GoalKind.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            switch goalKind {
            case .none:
                EmptyView()
            case .duration:
                Stepper(value: $goalMinutes, in: 5...180, step: 5) {
                    LabeledContent("時間", value: "\(Int(goalMinutes)) 分")
                }
            case .distance:
                Stepper(value: $goalDistance, in: 0.5...42, step: 0.5) {
                    LabeledContent("距離", value: String(format: "%.1f %@", goalDistance, units.distanceLabel))
                }
            case .kcal:
                Stepper(value: $goalKcal, in: 50...1500, step: 50) {
                    LabeledContent("消費カロリー", value: "\(Int(goalKcal)) kcal")
                }
            }
        }
    }
}

/// Live workout, then the summary once finished.
struct WorkoutFlowView: View {
    let model: WorkoutModel
    let onClose: () -> Void

    var body: some View {
        Group {
            if let record = model.finishedRecord {
                SummaryView(record: record, units: model.units, onClose: onClose)
            } else {
                WorkoutView(model: model, onCancel: {
                    model.cancel()
                    onClose()
                })
            }
        }
        .onAppear { model.start() }
    }
}
