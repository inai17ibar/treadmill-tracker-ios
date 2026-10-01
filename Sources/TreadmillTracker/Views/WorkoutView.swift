import SwiftUI
import TreadmillKit

/// Live screen, laid out for a phone resting on the treadmill console: big numbers and big buttons.
struct WorkoutView: View {
    let model: WorkoutModel
    let onCancel: () -> Void
    @State private var confirmFinish = false

    private var units: UnitSystem { model.units }

    var body: some View {
        let m = model.metrics
        let session = model.session
        VStack(spacing: 12) {
            if let program = model.program, let pos = model.programPosition {
                programBanner(program, pos)
            } else if let progress = model.goalProgress {
                ProgressView(value: progress) {
                    Text(progress >= 1 ? "目標達成！" : "目標 \(Int(progress * 100))%").font(.caption.bold())
                }
                .tint(progress >= 1 ? Color.green : Color.accentColor)
            }

            Text(Format.duration(m.activeDuration))
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(model.isRunning ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topTrailing) {
                    if session.state == .paused {
                        Text("一時停止中").font(.caption.bold()).padding(6).background(.yellow, in: Capsule())
                    }
                }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                MetricTile(title: "距離", value: units.distanceText(meters: m.distanceMeters), unit: units.distanceLabel)
                MetricTile(title: "消費", value: Format.kcal(m.activeKcal), unit: "kcal")
                MetricTile(title: "ペース", value: units.paceText(speedKmh: session.speedKmh), unit: units.paceLabel)
                MetricTile(title: "強度", value: String(format: "%.1f", session.currentRate.mets), unit: "METs")
                MetricTile(title: "上昇", value: String(format: "%.0f", m.elevationMeters), unit: "m")
                MetricTile(title: model.cadence != nil ? "ピッチ" : "歩数",
                           value: model.cadence.map { String(format: "%.0f", $0) } ?? "\(model.steps)",
                           unit: model.cadence != nil ? "歩/分" : "歩")
            }

            ControlRow(title: "速度", value: units.speedText(kmh: session.speedKmh), unit: units.speedLabel,
                       small: 0.1, large: 1.0) { model.changeSpeed(by: $0) }
            ControlRow(title: "傾斜", value: Format.percent(session.inclinePercent), unit: "%",
                       small: 0.5, large: 1.0) { model.changeIncline(by: $0) }

            Picker("歩く / 走る", selection: Binding(get: { session.gaitMode }, set: { model.setGaitMode($0) })) {
                ForEach(GaitMode.allCases, id: \.self) { mode in
                    Text(mode == .auto ? "自動（\(session.gait == .run ? "走" : "歩")）" : mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button {
                    model.togglePause()
                } label: {
                    Label(model.isRunning ? "一時停止" : "再開", systemImage: model.isRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(model.isRunning ? .orange : .green)

                Button(role: .destructive) {
                    confirmFinish = true
                } label: {
                    Label("終了", systemImage: "stop.fill").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            .font(.title3.bold())
        }
        .padding()
        .confirmationDialog("ワークアウトを終了しますか？", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("終了して記録する") { model.finish() }
            Button("記録せずに破棄", role: .destructive) { onCancel() }
            Button("続ける", role: .cancel) {}
        }
    }

    private func programBanner(_ program: WorkoutProgram, _ pos: ProgramPosition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pos.isComplete ? "\(program.name) 完了" : "\(pos.stepIndex + 1)/\(program.steps.count)  \(pos.step?.label ?? "")")
                    .font(.headline)
                Spacer()
                if !pos.isComplete {
                    Text(Format.duration(pos.remainingInStep)).font(.title2.bold()).monospacedDigit()
                }
            }
            ProgressView(value: pos.isComplete ? 1 : pos.stepProgress)
            if let next = pos.next, !pos.isComplete {
                Text("次: \(next.label)  \(units.speedText(kmh: next.speedKmh)) \(units.speedLabel)・傾斜 \(Format.percent(next.inclinePercent))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if pos.isComplete {
                Text("このまま続けるか「終了」で記録します").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// −large / −small / value / +small / +large; mirrors the treadmill's buttons.
private struct ControlRow: View {
    let title: String
    let value: String
    let unit: String
    let small: Double
    let large: Double
    let change: (Double) -> Void

    var body: some View {
        HStack(spacing: 6) {
            step(-large, "minus.circle.fill", "−\(label(large))")
            step(-small, "minus", "−\(label(small))")
            VStack(spacing: 0) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value).font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            step(small, "plus", "+\(label(small))")
            step(large, "plus.circle.fill", "+\(label(large))")
        }
    }

    private func label(_ v: Double) -> String { String(format: v < 1 ? "%.1f" : "%.0f", v) }

    private func step(_ delta: Double, _ icon: String, _ text: String) -> some View {
        Button {
            change(delta)
        } label: {
            VStack(spacing: 0) {
                Image(systemName: icon).font(.title3)
                Text(text).font(.caption2)
            }
            .frame(width: 52, height: 52)
        }
        .buttonStyle(.bordered)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel("\(title) \(text)")
    }
}
