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
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("トレッドミル")
                    .font(Theme.headline(40))
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("メニュー")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            menuCard(id: "", name: "フリー", summary: "速度と傾斜を自由に変えて記録")
                            ForEach(WorkoutProgram.presets) { p in
                                menuCard(id: p.id, name: p.name, summary: p.summary)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.horizontal, -20)
                    .sensoryFeedback(.selection, trigger: programID)
                }

                if let program {
                    programSection(program)
                } else {
                    freeSections
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("歩く / 走る")
                    ChipPicker(options: GaitMode.allCases, selection: $gaitMode) { $0.displayName }
                    Text("カロリーの計算式を切り替えます。自動は時速 \(Format.percent(Metabolic.autoRunThresholdKmh)) km 以上を「走る」とします。")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { startButton }
        .fullScreenCover(item: $active) { workout in
            WorkoutFlowView(model: workout.model) { active = nil }
        }
    }

    private var startButton: some View {
        Button {
            let setup = WorkoutSetup(program: program, speedKmh: speedKmh, inclinePercent: inclinePercent,
                                     gaitMode: gaitMode, goal: goal)
            active = ActiveWorkout(model: WorkoutModel(setup: setup, weightKg: weightKg, units: units,
                                                       voiceEnabled: voiceEnabled))
        } label: {
            Text("スタート")
                .font(Theme.headline(24))
                .foregroundStyle(.black)
                .frame(width: 116, height: 116)
                .background(Theme.volt, in: Circle())
                .shadow(color: Theme.volt.opacity(0.35), radius: 16)
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.impact(weight: .heavy), trigger: active?.id)
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [Theme.background.opacity(0), Theme.background], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
    }

    private func menuCard(id: String, name: String, summary: String) -> some View {
        let selected = programID == id
        return Button {
            programID = id
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(Theme.headline(22))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(summary)
                    .font(.caption.weight(.medium))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .opacity(0.75)
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? .black : .white)
            .padding(16)
            .frame(width: 190, height: 130, alignment: .topLeading)
            .background(selected ? Theme.volt : Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func programSection(_ program: WorkoutProgram) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("内容")
            HStack(alignment: .top) {
                StatColumn(value: Format.duration(program.totalDuration), label: "時間")
                StatColumn(value: units.distanceText(meters: program.totalDistanceMeters), label: "距離 \(units.distanceLabel)")
                StatColumn(value: Format.kcal(program.estimatedActiveKcal(weightKg: weightKg, gaitMode: gaitMode)), label: "消費 kcal")
            }
            .padding(.vertical, 16)
            .card()
            ValueStepper(title: "速度の強さ", value: $intensity, range: 0.7...1.3, step: 0.05) {
                "\(Int(($0 * 100).rounded()))%"
            }
            DisclosureGroup {
                VStack(spacing: 10) {
                    ForEach(Array(program.steps.enumerated()), id: \.offset) { _, step in
                        HStack {
                            Text(step.label)
                            Spacer()
                            Text("\(Format.duration(step.duration))・\(units.speedText(kmh: step.speedKmh)) \(units.speedLabel)・\(Format.percent(step.inclinePercent))%")
                                .monospacedDigit()
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .font(.callout)
                    }
                }
                .padding(.top, 10)
            } label: {
                Text("ステップ（\(program.steps.count)）").font(.headline).foregroundStyle(.white)
            }
            .padding(16)
            .card()
        }
    }

    @ViewBuilder
    private var freeSections: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("スタート時の設定")
            ValueStepper(title: "速度 \(units.speedLabel)", value: displayedSpeed,
                         range: units.speed(fromKmh: TreadmillLimits.speedKmh.lowerBound)...units.speed(fromKmh: TreadmillLimits.speedKmh.upperBound),
                         step: 0.1) { _ in units.speedText(kmh: speedKmh) }
            ValueStepper(title: "傾斜 %", value: $inclinePercent, range: TreadmillLimits.inclinePercent, step: 0.5) {
                Format.percent($0)
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("目標")
            ChipPicker(options: GoalKind.allCases, selection: $goalKind) { $0.displayName }
            switch goalKind {
            case .none:
                EmptyView()
            case .duration:
                ValueStepper(title: "時間 分", value: $goalMinutes, range: 5...180, step: 5) { "\(Int($0))" }
            case .distance:
                ValueStepper(title: "距離 \(units.distanceLabel)", value: $goalDistance, range: 0.5...42, step: 0.5) {
                    String(format: "%.1f", $0)
                }
            case .kcal:
                ValueStepper(title: "消費 kcal", value: $goalKcal, range: 50...1500, step: 50) { "\(Int($0))" }
            }
        }
    }
}

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(Theme.headline(22))
    }
}

private struct StatColumn: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.number(30)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            MetricLabel(label)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Big number between − and + buttons; long press repeats.
private struct ValueStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        HStack {
            button("minus", delta: -step).disabled(value <= range.lowerBound)
            VStack(spacing: 2) {
                Text(format(value))
                    .font(Theme.number(40))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                MetricLabel(title)
            }
            .frame(maxWidth: .infinity)
            button("plus", delta: step).disabled(value >= range.upperBound)
        }
        .padding(12)
        .card()
        .sensoryFeedback(.selection, trigger: value)
    }

    private func button(_ icon: String, delta: Double) -> some View {
        Button {
            let next = ((value + delta) / step).rounded() * step
            value = min(max(next, range.lowerBound), range.upperBound)
        } label: {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Theme.surfaceHigh, in: Circle())
        }
        .buttonStyle(PressableStyle())
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel("\(title) \(delta < 0 ? "下げる" : "上げる")")
    }
}

private extension View {
    func card() -> some View {
        frame(maxWidth: .infinity).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
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
