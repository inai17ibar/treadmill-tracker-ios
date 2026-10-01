import SwiftUI
import TreadmillKit

/// Shown right after a workout: optional distance correction, then save to history (and Apple Health).
struct SummaryView: View {
    let units: UnitSystem
    let onClose: () -> Void

    @Environment(WorkoutStore.self) private var store
    @AppStorage(SettingsKey.saveToHealth) private var saveToHealth = true
    @State private var record: WorkoutRecord
    @State private var original: WorkoutRecord
    @State private var displayedDistance = ""
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var confirmDiscard = false

    init(record: WorkoutRecord, units: UnitSystem, onClose: @escaping () -> Void) {
        self.units = units
        self.onClose = onClose
        _record = State(initialValue: record)
        _original = State(initialValue: record)
    }

    var body: some View {
        NavigationStack {
            Form {
                RecordSections(record: record, units: units)

                Section {
                    HStack {
                        TextField("トレッドミルに表示された距離", text: $displayedDistance)
                            .keyboardType(.decimalPad)
                        Text(units.distanceLabel).foregroundStyle(.secondary)
                    }
                    Button("この距離に合わせる") {
                        guard let value = Double(displayedDistance.replacingOccurrences(of: ",", with: ".")), value > 0 else { return }
                        record = original.correctingDistance(to: units.meters(fromDistance: value))
                    }
                    .disabled(Double(displayedDistance.replacingOccurrences(of: ",", with: ".")) == nil)
                    if record != original {
                        Button("補正を取り消す") {
                            record = original
                            displayedDistance = ""
                        }
                    }
                } header: {
                    Text("距離の補正")
                } footer: {
                    Text("速度の変更を記録し忘れたときは、トレッドミルの表示距離を入力すると全区間の速度を同じ比率で補正し、カロリーも再計算します。")
                }

                if HealthKitService.shared.isAvailable {
                    Section {
                        Toggle("ヘルスケアに保存", isOn: $saveToHealth)
                    } footer: {
                        Text("屋内\(record.primaryGait == .run ? "ランニング" : "ウォーキング")として、距離とアクティブエネルギーを保存します。")
                    }
                }
            }
            .navigationTitle(record.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("破棄", role: .destructive) { confirmDiscard = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        Button("保存") { Task { await save() } }.bold()
                    }
                }
            }
            .confirmationDialog("この記録を破棄しますか？", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("破棄", role: .destructive) { onClose() }
            }
            .alert("ヘルスケアに保存できませんでした", isPresented: Binding(get: { errorMessage != nil },
                                                                 set: { if !$0 { errorMessage = nil; onClose() } })) {
                Button("OK") {}
            } message: {
                Text((errorMessage ?? "") + "\n記録はアプリ内に保存しました。")
            }
            .interactiveDismissDisabled()
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        var r = record
        var failure: String?
        if saveToHealth, HealthKitService.shared.isAvailable {
            do {
                try await HealthKitService.shared.save(r)
                r.savedToHealth = true
            } catch {
                failure = error.localizedDescription
            }
        }
        store.add(r)
        if let failure {
            errorMessage = failure
        } else {
            onClose()
        }
    }
}
