import SwiftUI
import TreadmillKit

private struct ActiveWorkout: Identifiable {
    let id = UUID()
    let model: WorkoutModel
}

struct HomeView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var choosingProgram = false
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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TREADMILL")
                            .font(.caption.weight(.bold)).tracking(3)
                            .foregroundStyle(Theme.secondary)
                        Text(L10n.text("今日も、一歩先へ。"))
                            .font(.system(size: 32, weight: .heavy))
                        Text(L10n.text("屋内でも、積み重ねよう。"))
                            .font(.subheadline).foregroundStyle(Theme.secondary)
                    }
                    .padding(.top, 12)

                    let week = WorkoutTotals.week(of: Date(), records: store.records)
                    HStack(spacing: 16) {
                        SportMetric(title: L10n.text("今週の距離"), value: units.distanceText(meters: week.distanceMeters), unit: units.distanceLabel)
                        Rectangle().fill(Theme.secondary.opacity(0.2)).frame(width: 1)
                        SportMetric(title: L10n.text("運動時間"), value: Format.duration(week.activeDuration))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .sportCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.text("今日のメニュー")).font(.headline)
                        menuCard
                        Button { choosingProgram = true } label: {
                            HStack {
                                Text(L10n.text("メニューを変更"))
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.secondary)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.text)
                            .sportCard()
                        }
                        .buttonStyle(.plain)
                    }

                    if let program {
                        programSection(program)
                    } else {
                        freeSections
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.text("歩く / 走る")).font(.headline)
                        Picker(L10n.text("歩く / 走る"), selection: $gaitMode) {
                            ForEach(GaitMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Text(L10n.format("自動は時速 %@ km 以上で走行の計算式に切り替わります。", String(describing: Format.percent(Metabolic.autoRunThresholdKmh))))
                            .font(.caption).foregroundStyle(Theme.secondary)
                    }
                    .sportCard()
                }
                .padding(20)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(action: startWorkout) {
                    Label(L10n.text("スタート"), systemImage: "play.fill").font(.title3.bold())
                }
                .buttonStyle(SportButtonStyle())
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Theme.background)
            }
            .sheet(isPresented: $choosingProgram) { programPicker }
        }
        .fullScreenCover(item: $active) { workout in
            WorkoutFlowView(model: workout.model) { active = nil }
        }
    }

    private var menuCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(program == nil ? "FREE WORKOUT" : "TRAINING PROGRAM")
                    .font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(Theme.lime)
                Spacer()
                Image(systemName: program == nil ? "figure.run.treadmill" : "chart.bar.xaxis")
                    .font(.title2).foregroundStyle(Theme.lime)
            }
            Text(program?.localizedName ?? L10n.text("フリーワークアウト"))
                .font(.system(size: 24, weight: .bold))
            Text(program?.localizedSummary ?? L10n.text("自分のペースで、速度と傾斜を自由に。"))
                .font(.subheadline).foregroundStyle(Theme.secondary)
            HStack(spacing: 12) {
                SportMetric(title: L10n.text("時間"), value: program.map { Format.duration($0.totalDuration) } ?? L10n.text("自由"), size: 24)
                SportMetric(title: L10n.text("開始速度"), value: units.speedText(kmh: program?.steps.first?.speedKmh ?? speedKmh), unit: units.speedLabel, size: 24)
                SportMetric(title: L10n.text("開始傾斜"), value: Format.percent(program?.steps.first?.inclinePercent ?? inclinePercent), unit: "%", size: 24)
            }
        }
        .sportCard(accent: Theme.lime)
    }

    private var programPicker: some View {
        NavigationStack {
            List {
                programChoice(id: "", name: L10n.text("フリーワークアウト"), summary: L10n.text("速度と傾斜を自由に変えて記録"))
                ForEach(WorkoutProgram.presets) { p in
                    programChoice(id: p.id, name: p.localizedName, summary: p.localizedSummary)
                }
            }
            .sportForm()
            .navigationTitle(L10n.text("メニューを選択"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("完了")) { choosingProgram = false }
                }
            }
        }
    }

    private func programChoice(id: String, name: String, summary: String) -> some View {
        Button {
            programID = id
            choosingProgram = false
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(name).font(.headline).foregroundStyle(Theme.text)
                    Text(summary).font(.caption).foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 4)
                if programID == id {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.lime)
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Theme.surface)
    }

    private func startWorkout() {
        let setup = WorkoutSetup(program: program, speedKmh: speedKmh, inclinePercent: inclinePercent,
                                 gaitMode: gaitMode, goal: goal)
        active = ActiveWorkout(model: WorkoutModel(setup: setup, weightKg: weightKg, units: units,
                                                   voiceEnabled: voiceEnabled))
    }

    @ViewBuilder
    private func programSection(_ program: WorkoutProgram) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("メニューの調整")).font(.headline)
            LabeledContent(L10n.text("時間"), value: Format.duration(program.totalDuration))
            LabeledContent(L10n.text("距離の目安"), value: "\(units.distanceText(meters: program.totalDistanceMeters)) \(units.distanceLabel)")
            LabeledContent(L10n.text("消費カロリーの目安"),
                           value: "\(Format.kcal(program.estimatedActiveKcal(weightKg: weightKg, gaitMode: gaitMode))) kcal")
            Stepper(value: $intensity, in: 0.7...1.3, step: 0.05) {
                LabeledContent(L10n.text("速度の強さ"), value: "\(Int((intensity * 100).rounded()))%")
            }
            DisclosureGroup(L10n.format("ステップ（%@）", String(describing: program.steps.count))) {
                ForEach(Array(program.steps.enumerated()), id: \.offset) { _, step in
                    HStack {
                        Text(step.localizedLabel)
                        Spacer()
                        Text("\(Format.duration(step.duration))・\(units.speedText(kmh: step.speedKmh)) \(units.speedLabel)・\(Format.percent(step.inclinePercent))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
        }
        .sportCard()
    }

    @ViewBuilder
    private var freeSections: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("スタート時の設定")).font(.headline)
            Stepper(value: displayedSpeed, in: units.speed(fromKmh: TreadmillLimits.speedKmh.lowerBound)...units.speed(fromKmh: TreadmillLimits.speedKmh.upperBound), step: 0.1) {
                LabeledContent(L10n.text("速度"), value: "\(units.speedText(kmh: speedKmh)) \(units.speedLabel)")
            }
            Stepper(value: $inclinePercent, in: TreadmillLimits.inclinePercent, step: 0.5) {
                LabeledContent(L10n.text("傾斜"), value: "\(Format.percent(inclinePercent))%")
            }
        }
        .sportCard()

        VStack(alignment: .leading, spacing: 16) {
            Label(L10n.text("目標"), systemImage: "scope").font(.headline)
            Picker(L10n.text("目標"), selection: $goalKind) {
                ForEach(GoalKind.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            switch goalKind {
            case .none:
                EmptyView()
            case .duration:
                Stepper(value: $goalMinutes, in: 5...180, step: 5) {
                    LabeledContent(L10n.text("時間"), value: L10n.format("%@ 分", String(describing: Int(goalMinutes))))
                }
            case .distance:
                Stepper(value: $goalDistance, in: 0.5...42, step: 0.5) {
                    LabeledContent(L10n.text("距離"), value: String(format: "%.1f %@", goalDistance, units.distanceLabel))
                }
            case .kcal:
                Stepper(value: $goalKcal, in: 50...1500, step: 50) {
                    LabeledContent(L10n.text("消費カロリー"), value: "\(Int(goalKcal)) kcal")
                }
            }
        }
        .sportCard()
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
