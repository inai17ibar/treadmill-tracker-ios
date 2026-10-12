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
                        TextField(L10n.text("トレッドミルに表示された距離"), text: $displayedDistance)
                            .keyboardType(.decimalPad)
                        Text(units.distanceLabel).foregroundStyle(.secondary)
                    }
                    Button(L10n.text("この距離に合わせる")) {
                        guard let value = Double(displayedDistance.replacingOccurrences(of: ",", with: ".")), value > 0 else { return }
                        record = original.correctingDistance(to: units.meters(fromDistance: value))
                    }
                    .disabled(Double(displayedDistance.replacingOccurrences(of: ",", with: ".")) == nil)
                    if record != original {
                        Button(L10n.text("補正を取り消す")) {
                            record = original
                            displayedDistance = ""
                        }
                    }
                } header: {
                    Text(L10n.text("距離の補正"))
                } footer: {
                    Text(L10n.text("速度の変更を記録し忘れたときは、トレッドミルの表示距離を入力すると全区間の速度を同じ比率で補正し、カロリーも再計算します。"))
                }

                if HealthKitService.shared.isAvailable {
                    Section {
                        Toggle(L10n.text("ヘルスケアに保存"), isOn: $saveToHealth)
                    } footer: {
                        Text(L10n.format("屋内%@として、距離とアクティブエネルギーを保存します。", String(describing: record.primaryGait == .run ? L10n.text("ランニング") : L10n.text("ウォーキング"))))
                    }
                }
            }
            .sportForm()
            .navigationTitle(record.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("破棄"), role: .destructive) { confirmDiscard = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        Button(L10n.text("保存")) { Task { await save() } }.bold()
                    }
                }
            }
            .confirmationDialog(L10n.text("この記録を破棄しますか？"), isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button(L10n.text("破棄"), role: .destructive) { onClose() }
            }
            .alert(L10n.text("ヘルスケアに保存できませんでした"), isPresented: Binding(get: { errorMessage != nil },
                                                                 set: { if !$0 { errorMessage = nil; onClose() } })) {
                Button("OK") {}
            } message: {
                Text((errorMessage ?? "") + L10n.text("\n記録はアプリ内に保存しました。"))
            }
            .interactiveDismissDisabled()
        }
    }

    private func save() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        var r = record
        // Keep the completed workout even if HealthKit is interrupted or the app exits.
        store.add(r)
        var failure: String?
        if saveToHealth, HealthKitService.shared.isAvailable {
            do {
                try await HealthKitService.shared.save(r)
                r.savedToHealth = true
            } catch {
                failure = error.localizedDescription
            }
        }
        store.update(r)
        if let failure {
            errorMessage = failure
        } else {
            onClose()
        }
    }
}
