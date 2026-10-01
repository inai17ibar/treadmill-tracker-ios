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
                        Section("今週") {
                            let week = WorkoutTotals.week(of: Date(), records: store.records)
                            HStack {
                                total("回数", "\(week.count)")
                                total("時間", Format.duration(week.activeDuration))
                                total("距離", "\(units.distanceText(meters: week.distanceMeters)) \(units.distanceLabel)")
                                total("消費", "\(Format.kcal(week.activeKcal)) kcal")
                            }
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
        }
    }

    private func total(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold()).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ record: WorkoutRecord) -> some View {
        let m = record.metrics
        return HStack {
            Image(systemName: record.primaryGait == .run ? "figure.run" : "figure.walk")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title).font(.headline)
                Text(record.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(units.distanceText(meters: m.distanceMeters)) \(units.distanceLabel)").font(.headline).monospacedDigit()
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
