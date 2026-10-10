import SwiftUI
import TreadmillKit

struct HistoryView: View {
    @Environment(WorkoutStore.self) private var store
    @AppStorage(SettingsKey.units) private var units: UnitSystem = .metric

    var body: some View {
        NavigationStack {
            Group {
                if store.records.isEmpty {
                    ContentUnavailableView("まだ記録がありません", systemImage: "figure.walk",
                                           description: Text("ワークアウトを終了すると、ここに保存されます。"))
                } else {
                    List {
                        Section {
                            let week = WorkoutTotals.week(of: Date(), records: store.records)
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 0) {
                                    MetricLabel("今週")
                                    Text(units.distanceText(meters: week.distanceMeters))
                                        .font(Theme.number(72))
                                        .monospacedDigit()
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                    Text(units == .metric ? "キロメートル" : "マイル")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                HStack {
                                    total("回数", "\(week.count)")
                                    total("時間", Format.duration(week.activeDuration))
                                    total("消費 kcal", Format.kcal(week.activeKcal))
                                }
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                        }
                        Section("記録") {
                            ForEach(store.records) { record in
                                NavigationLink {
                                    RecordDetailView(recordID: record.id)
                                } label: {
                                    row(record)
                                }
                            }
                            .onDelete { offsets in
                                store.delete(Set(offsets.map { store.records[$0].id }))
                            }
                        }
                    }
                }
            }
            .navigationTitle("履歴")
            .scrollContentBackground(.hidden)
            .background(Theme.background)
        }
    }

    private func total(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(Theme.number(26)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            MetricLabel(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ record: WorkoutRecord) -> some View {
        let m = record.metrics
        return HStack {
            Image(systemName: record.primaryGait == .run ? "figure.run" : "figure.walk")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.black)
                .frame(width: 40, height: 40)
                .background(Theme.volt, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title).font(.headline)
                Text(record.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(units.distanceText(meters: m.distanceMeters)) \(units.distanceLabel)").font(Theme.number(22)).monospacedDigit()
                Text("\(Format.duration(m.activeDuration))・\(Format.kcal(m.activeKcal)) kcal")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RecordDetailView: View {
    let recordID: UUID
    @Environment(WorkoutStore.self) private var store
    @AppStorage(SettingsKey.units) private var units: UnitSystem = .metric
    @State private var saving = false
    @State private var message: String?

    var body: some View {
        if let record = store.records.first(where: { $0.id == recordID }) {
            Form {
                RecordSections(record: record, units: units)
                if HealthKitService.shared.isAvailable {
                    Section {
                        if record.savedToHealth {
                            Label("ヘルスケアに保存済み", systemImage: "checkmark.circle").foregroundStyle(.secondary)
                        } else {
                            Button {
                                Task { await saveToHealth(record) }
                            } label: {
                                if saving { ProgressView() } else { Label("ヘルスケアに保存", systemImage: "heart") }
                            }
                            .disabled(saving)
                        }
                    }
                }
            }
            .navigationTitle(record.title)
            .navigationBarTitleDisplayMode(.inline)
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") {}
            }
        } else {
            ContentUnavailableView("記録が見つかりません", systemImage: "questionmark")
        }
    }

    private func saveToHealth(_ record: WorkoutRecord) async {
        saving = true
        defer { saving = false }
        do {
            try await HealthKitService.shared.save(record)
            var r = record
            r.savedToHealth = true
            store.update(r)
        } catch {
            message = error.localizedDescription
        }
    }
}
