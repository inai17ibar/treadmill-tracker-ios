import SwiftUI
import TreadmillKit

/// Live screen, laid out for a phone resting on the treadmill console: big numbers and big buttons.
/// Volt while running, black while paused.
struct WorkoutView: View {
    let model: WorkoutModel
    let onCancel: () -> Void
    @State private var confirmFinish = false

    private var units: UnitSystem { model.units }
    private var fg: Color { model.isRunning ? .black : .white }
    private var bg: Color { model.isRunning ? Theme.volt : Theme.background }

    var body: some View {
        let m = model.metrics
        let session = model.session
        VStack(spacing: 0) {
            // Scrolls on short screens (e.g. iPhone SE) so nothing gets clipped; pause/finish stay pinned below.
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 12) {
                        if let program = model.program, let pos = model.programPosition {
                            programBanner(program, pos)
                        } else if let progress = model.goalProgress {
                            goalBar(progress)
                        }

                        HStack(alignment: .top) {
                            SmallMetric(label: "ペース", value: units.paceText(speedKmh: session.speedKmh), unit: units.paceLabel, color: fg)
                            SmallMetric(label: "時間", value: Format.duration(m.activeDuration), unit: nil, color: fg)
                            SmallMetric(label: "消費", value: Format.kcal(m.activeKcal), unit: "kcal", color: fg)
                        }

                        VStack(spacing: 0) {
                            if session.state == .paused {
                                Text("一時停止中")
                                    .font(Theme.headline(20))
                                    .foregroundStyle(Theme.volt)
                            }
                            Text(units.distanceText(meters: m.distanceMeters))
                                .font(Theme.number(model.program == nil ? 120 : 88))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText())
                            Text(units == .metric ? "キロメートル" : "マイル")
                                .font(.headline.weight(.bold))
                                .opacity(0.7)
                        }
                        .foregroundStyle(fg)
                        .frame(maxWidth: .infinity)

                        HStack(alignment: .top) {
                            SmallMetric(label: "強度", value: String(format: "%.1f", session.currentRate.mets), unit: "METs", color: fg)
                            SmallMetric(label: "上昇", value: String(format: "%.0f", m.elevationMeters), unit: "m", color: fg)
                            SmallMetric(label: model.cadence != nil ? "ピッチ" : "歩数",
                                        value: model.cadence.map { String(format: "%.0f", $0) } ?? "\(model.steps)",
                                        unit: model.cadence != nil ? "歩/分" : "歩", color: fg)
                        }

                        Spacer(minLength: 0)

                        VStack(spacing: 10) {
                            ControlRow(title: "速度", value: units.speedText(kmh: session.speedKmh), unit: units.speedLabel,
                                       small: 0.1, large: 1.0, fg: fg, bg: bg) { model.changeSpeed(by: $0) }
                            ControlRow(title: "傾斜", value: Format.percent(session.inclinePercent), unit: "%",
                                       small: 0.5, large: 1.0, fg: fg, bg: bg) { model.changeIncline(by: $0) }
                            ChipPicker(options: GaitMode.allCases,
                                       selection: Binding(get: { session.gaitMode }, set: { model.setGaitMode($0) }),
                                       foreground: fg, accent: fg, accentText: bg) { mode in
                                mode == .auto ? "自動（\(session.gait == .run ? "走" : "歩")）" : mode.displayName
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }

            controls
                .padding(.vertical, 8)
        }
        .padding(.horizontal, 20)
        .background(bg.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: model.isRunning)
        .preferredColorScheme(model.isRunning ? .light : .dark)
        .confirmationDialog("ワークアウトを終了しますか？", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("終了して記録する") { model.finish() }
            Button("記録せずに破棄", role: .destructive) { onCancel() }
            Button("続ける", role: .cancel) {}
        }
    }

    /// Running: one big pause button. Paused: stop and resume.
    private var controls: some View {
        HStack(spacing: 40) {
            if model.isRunning {
                RoundButton(icon: "pause.fill", label: "一時停止", size: 92, fill: .black, iconColor: Theme.volt) {
                    model.togglePause()
                }
            } else {
                RoundButton(icon: "stop.fill", label: "終了", size: 84, fill: .white, iconColor: .black) {
                    confirmFinish = true
                }
                RoundButton(icon: "play.fill", label: "再開", size: 84, fill: Theme.volt, iconColor: .black) {
                    model.togglePause()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.impact(weight: .medium), trigger: model.isRunning)
    }

    private func goalBar(_ progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MetricLabel(progress >= 1 ? "目標達成！" : "目標 \(Int(progress * 100))%", color: fg)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(fg.opacity(0.15))
                    Capsule().fill(fg).frame(width: geo.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 6)
        }
    }

    private func programBanner(_ program: WorkoutProgram, _ pos: ProgramPosition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(pos.isComplete ? "\(program.name) 完了" : "\(pos.stepIndex + 1)/\(program.steps.count)  \(pos.step?.label ?? "")")
                    .font(Theme.headline(20))
                    .lineLimit(1)
                Spacer()
                if !pos.isComplete {
                    Text(Format.duration(pos.remainingInStep)).font(Theme.number(28)).monospacedDigit()
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(fg.opacity(0.15))
                    Capsule().fill(fg).frame(width: geo.size.width * (pos.isComplete ? 1 : pos.stepProgress))
                }
            }
            .frame(height: 6)
            if let next = pos.next, !pos.isComplete {
                Text("次: \(next.label)  \(units.speedText(kmh: next.speedKmh)) \(units.speedLabel)・傾斜 \(Format.percent(next.inclinePercent))%")
                    .font(.caption.weight(.semibold))
                    .opacity(0.7)
            } else if pos.isComplete {
                Text("このまま続けるか「終了」で記録します").font(.caption.weight(.semibold)).opacity(0.7)
            }
        }
        .foregroundStyle(fg)
        .padding(14)
        .background(fg.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct SmallMetric: View {
    let label: String
    let value: String
    let unit: String?
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.number(30))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            MetricLabel(unit.map { "\(label) \($0)" } ?? label, color: color.opacity(0.6))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
    }
}

private struct RoundButton: View {
    let icon: String
    let label: String
    let size: CGFloat
    let fill: Color
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: size, height: size)
                .background(fill, in: Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

/// −large / −small / value / +small / +large; mirrors the treadmill's buttons.
private struct ControlRow: View {
    let title: String
    let value: String
    let unit: String
    let small: Double
    let large: Double
    let fg: Color
    let bg: Color
    let change: (Double) -> Void

    var body: some View {
        HStack(spacing: 8) {
            step(-large, "−\(label(large))", strong: true)
            step(-small, "−\(label(small))", strong: false)
            VStack(spacing: 0) {
                Text(value)
                    .font(Theme.number(40))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                MetricLabel("\(title) \(unit)", color: fg.opacity(0.6))
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity)
            .layoutPriority(1)
            step(small, "+\(label(small))", strong: false)
            step(large, "+\(label(large))", strong: true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(fg.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        .sensoryFeedback(.selection, trigger: value)
    }

    private func label(_ v: Double) -> String { String(format: v < 1 ? "%.1f" : "%.0f", v) }

    private func step(_ delta: Double, _ text: String, strong: Bool) -> some View {
        Button {
            change(delta)
        } label: {
            Text(text)
                .font(.system(size: 15, weight: .heavy).width(.condensed))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(strong ? bg : fg)
                .frame(width: 50, height: 50)
                .background(strong ? fg : fg.opacity(0.12), in: Circle())
        }
        .buttonStyle(PressableStyle())
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel("\(title) \(text)")
    }
}
