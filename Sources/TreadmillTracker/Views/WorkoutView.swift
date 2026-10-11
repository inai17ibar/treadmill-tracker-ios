import SwiftUI
import TreadmillKit

/// Large controls and pinned actions for a phone resting on a treadmill console.
struct WorkoutView: View {
    let model: WorkoutModel
    let onCancel: () -> Void
    @State private var confirmFinish = false

    private var units: UnitSystem { model.units }

    var body: some View {
        let m = model.metrics
        let session = model.session
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.program?.name ?? "フリーワークアウト")
                        .font(.headline)
                    Spacer(minLength: 8)
                    Label(model.isRunning ? "計測中" : "一時停止中", systemImage: model.isRunning ? "circle.fill" : "pause.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(model.isRunning ? Theme.lime : Theme.orange)
                }
                if let program = model.program, let pos = model.programPosition {
                    programBanner(program, pos)
                } else if let progress = model.goalProgress {
                    ProgressView(value: min(1, progress)) {
                        Text(progress >= 1 ? "目標達成！" : "目標 \(Int(progress * 100))%")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
                    }
                }

                VStack(spacing: 2) {
                    Text("経過時間").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
                    Text(Format.duration(m.activeDuration))
                        .font(.system(size: 78, weight: .heavy))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.45)
                        .foregroundStyle(model.isRunning ? Theme.text : Theme.secondary)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityElement(children: .combine)
                HStack(spacing: 20) {
                    SportMetric(title: "距離", value: units.distanceText(meters: m.distanceMeters), unit: units.distanceLabel, size: 34)
                    Rectangle().fill(Theme.secondary.opacity(0.2)).frame(width: 1)
                    SportMetric(title: "消費カロリー", value: Format.kcal(m.activeKcal), unit: "kcal", size: 34)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)

                ControlRow(title: "速度", value: units.speedText(kmh: session.speedKmh), unit: units.speedLabel,
                           small: 0.1, large: 1, accent: Theme.lime) { model.changeSpeed(by: $0) }
                ControlRow(title: "傾斜", value: Format.percent(session.inclinePercent), unit: "%",
                           small: 0.5, large: 1, accent: Theme.orange) { model.changeIncline(by: $0) }

                HStack(spacing: 16) {
                    SportMetric(title: "ペース", value: units.paceText(speedKmh: session.speedKmh), unit: units.paceLabel, size: 23)
                    SportMetric(title: "歩数", value: "\(model.steps)", unit: "歩", size: 23)
                }
                .sportCard()

                DisclosureGroup {
                    HStack(spacing: 12) {
                        SportMetric(title: "強度", value: String(format: "%.1f", session.currentRate.mets), unit: "METs", size: 22)
                        SportMetric(title: "上昇", value: String(format: "%.0f", m.elevationMeters), unit: "m", size: 22)
                        if let cadence = model.cadence {
                            SportMetric(title: "ピッチ", value: String(format: "%.0f", cadence), unit: "歩/分", size: 22)
                        }
                    }
                    .padding(.vertical, 12)
                    Picker("歩く / 走る", selection: Binding(get: { session.gaitMode }, set: { model.setGaitMode($0) })) {
                        ForEach(GaitMode.allCases, id: \.self) { mode in
                            Text(mode == .auto ? "自動（\(session.gait == .run ? "走" : "歩")）" : mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } label: {
                    Text("詳細と歩行・走行の切り替え")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondary)
                }
                .sportCard()
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 12) {
                Button { model.togglePause() } label: {
                    Label(model.isRunning ? "一時停止" : "再開", systemImage: model.isRunning ? "pause.fill" : "play.fill")
                }
                .buttonStyle(SportButtonStyle(fill: model.isRunning ? Theme.elevated : Theme.lime,
                                             foreground: model.isRunning ? Theme.text : Theme.background))
                Button(role: .destructive) { confirmFinish = true } label: {
                    Label("終了", systemImage: "stop.fill")
                }
                .buttonStyle(SportButtonStyle(fill: Theme.red, foreground: Theme.text))
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Theme.background)
        }
        .confirmationDialog("ワークアウトを終了しますか？", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("終了して記録する") { model.finish() }
            Button("記録せずに破棄", role: .destructive) { onCancel() }
            Button("続ける", role: .cancel) {}
        }
    }

    private func programBanner(_ program: WorkoutProgram, _ pos: ProgramPosition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pos.isComplete ? "メニュー完了" : "ステップ \(pos.stepIndex + 1) / \(program.steps.count) · \(pos.step?.label ?? "")")
                Spacer()
                if !pos.isComplete { Text(Format.duration(pos.remainingInStep)).monospacedDigit() }
            }
            .font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
            ProgressView(value: pos.isComplete ? 1 : pos.stepProgress)
            if let next = pos.next, !pos.isComplete {
                Text("次: \(next.label)  \(units.speedText(kmh: next.speedKmh)) \(units.speedLabel)・傾斜 \(Format.percent(next.inclinePercent))%")
                    .font(.caption).foregroundStyle(Theme.secondary)
            } else if pos.isComplete {
                Text("このまま続けるか「終了」で記録します").font(.caption).foregroundStyle(Theme.secondary)
            }
        }
    }
}

private struct ControlRow: View {
    let title: String
    let value: String
    let unit: String
    let small: Double
    let large: Double
    let accent: Color
    let change: (Double) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Spacer(minLength: 12)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value).font(.system(size: 54, weight: .heavy)).monospacedDigit()
                    Text(unit).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondary)
                }
                .lineLimit(1).minimumScaleFactor(0.55)
                .layoutPriority(1)
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: 8) {
                step(-large)
                step(-small)
                step(small)
                step(large)
            }
        }
        .sportCard()
    }

    private func step(_ delta: Double) -> some View {
        let magnitude = String(format: abs(delta) < 1 ? "%.1f" : "%.0f", abs(delta))
        let text = (delta < 0 ? "−" : "+") + magnitude
        return Button { change(delta) } label: {
            Text(text)
                .font(.system(size: 20, weight: .bold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(delta > 0 ? accent : Theme.text)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(delta > 0 ? accent.opacity(0.13) : Theme.elevated, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(delta > 0 ? accent.opacity(0.4) : Theme.text.opacity(0.08))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel("\(title) \(text) \(unit)")
    }
}
