import Charts
import SwiftUI
import TreadmillKit

/// Summary, charts, splits and segments of a workout; shown in the post-workout summary and in the history.
struct RecordSections: View {
    let record: WorkoutRecord
    let units: UnitSystem

    private struct ChartPoint: Identifiable {
        let id: Int
        let minutes: Double
        let speed: Double
        let incline: Double
    }

    private var points: [ChartPoint] {
        var t = 0.0
        var result: [ChartPoint] = []
        for seg in record.segments {
            let speed = units.speed(fromKmh: seg.speedKmh)
            result.append(ChartPoint(id: result.count, minutes: t / 60, speed: speed, incline: seg.inclinePercent))
            t += seg.duration
            result.append(ChartPoint(id: result.count, minutes: t / 60, speed: speed, incline: seg.inclinePercent))
        }
        return result
    }

    var body: some View {
        let m = record.metrics
        Section(L10n.text("概要")) {
            LabeledContent(L10n.text("日時"), value: record.startDate.formatted(date: .abbreviated, time: .shortened))
            LabeledContent(L10n.text("時間"), value: Format.duration(m.activeDuration))
            LabeledContent(L10n.text("距離"), value: "\(units.distanceText(meters: m.distanceMeters)) \(units.distanceLabel)")
            LabeledContent(L10n.text("消費カロリー（運動分）"), value: "\(Format.kcal(m.activeKcal)) kcal")
            if record.healthSummary == nil {
                LabeledContent(L10n.text("消費カロリー（安静時を含む）"), value: "\(Format.kcal(m.grossKcal)) kcal")
            }
            LabeledContent(L10n.text("平均速度"), value: "\(units.speedText(kmh: m.averageSpeedKmh)) \(units.speedLabel)")
            LabeledContent(L10n.text("平均ペース"), value: "\(units.paceText(speedKmh: m.averageSpeedKmh)) \(units.paceLabel)")
            if record.healthSummary == nil {
                LabeledContent(L10n.text("最大傾斜"), value: "\(Format.percent(record.maxInclinePercent))%")
            }
            if record.healthSummary == nil || record.healthSummary?.elevationMeters != nil {
                LabeledContent(L10n.text("上昇"), value: String(format: "%.0f m", m.elevationMeters))
            }
            if record.healthSummary != nil {
                Text(L10n.text("ヘルスケアから概要を復元した記録です。元の速度・傾斜の区間や体重は保存されていないため、表示できません。"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let steps = record.steps {
                LabeledContent(L10n.text("歩数"), value: L10n.format("%@ 歩", String(describing: steps)))
                if let stride = StepMetrics.strideMeters(distanceMeters: m.distanceMeters, steps: steps) {
                    LabeledContent(L10n.text("歩幅"), value: String(format: "%.0f cm", stride * 100))
                }
                if let cadence = StepMetrics.cadence(steps: steps, duration: m.activeDuration) {
                    LabeledContent(L10n.text("平均ピッチ"), value: String(format: L10n.text("%.0f 歩/分"), cadence))
                }
            }
            if record.distanceCorrection != 1 {
                LabeledContent(L10n.text("距離の補正"), value: String(format: "×%.3f", record.distanceCorrection))
            }
        }

        if !record.segments.isEmpty {
            Section(L10n.text("速度と傾斜")) {
                Chart(points) { p in
                    LineMark(x: .value(L10n.text("分"), p.minutes), y: .value(L10n.text("速度"), p.speed))
                        .foregroundStyle(Theme.lime)
                }
                .chartYAxisLabel(units.speedLabel)
                .frame(height: 140)
                Chart(points) { p in
                    AreaMark(x: .value(L10n.text("分"), p.minutes), y: .value(L10n.text("傾斜"), p.incline))
                        .foregroundStyle(Theme.orange.opacity(0.5))
                }
                .chartYAxisLabel("%")
                .chartXAxisLabel(L10n.text("分"))
                .frame(height: 100)
            }
        }

        let splits = record.splits(unitMeters: units.unitMeters)
        if !splits.isEmpty {
            Section(L10n.text("スプリット")) {
                ForEach(splits, id: \.index) { split in
                    HStack {
                        Text(split.distanceMeters >= units.unitMeters - 0.5
                             ? "\(split.index) \(units.distanceLabel)"
                             : "\(split.index - 1)+\(units.distanceText(meters: split.distanceMeters)) \(units.distanceLabel)")
                        Spacer()
                        Text(Format.duration(split.duration)).monospacedDigit()
                        Text("\(units.paceText(speedKmh: split.averageSpeedKmh))\(units.paceLabel)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .trailing)
                    }
                }
            }
        }

        if record.healthSummary == nil {
            Section(L10n.format("区間（%@）", String(describing: record.segments.count))) {
                ForEach(record.segments, id: \.self) { seg in
                    HStack {
                        Image(systemName: seg.gait == .run ? "figure.run" : "figure.walk")
                        Text("\(units.speedText(kmh: seg.speedKmh)) \(units.speedLabel)・\(Format.percent(seg.inclinePercent))%")
                            .monospacedDigit()
                        Spacer()
                        Text(Format.duration(seg.duration)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
        }
    }
}
