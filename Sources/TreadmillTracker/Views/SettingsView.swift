import SwiftUI
import TreadmillKit

struct SettingsView: View {
    @Environment(WorkoutStore.self) private var store
    @AppStorage(SettingsKey.weightKg) private var weightKg = 60.0
    @AppStorage(SettingsKey.heightCm) private var heightCm = 170.0
    @AppStorage(SettingsKey.units) private var units: UnitSystem = .metric
    @AppStorage(SettingsKey.voiceEnabled) private var voiceEnabled = true
    @AppStorage(SettingsKey.saveToHealth) private var saveToHealth = true
    @State private var message: String?
    @State private var restoring = false
    @State private var exporting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $weightKg, in: 25...250, step: 0.5) {
                        LabeledContent(L10n.text("体重"), value: String(format: "%.1f kg", weightKg))
                    }
                    Stepper(value: $heightCm, in: 100...230, step: 1) {
                        LabeledContent(L10n.text("身長"), value: String(format: "%.0f cm", heightCm))
                    }
                    if HealthKitService.shared.isAvailable {
                        Button(L10n.text("ヘルスケアから読み込む")) { Task { await loadFromHealth() } }
                    }
                } header: {
                    Text(L10n.text("プロフィール"))
                } footer: {
                    Text(L10n.text("消費カロリーは体重に比例します。正確な体重を設定してください。"))
                }

                Section(L10n.text("表示")) {
                    Picker(L10n.text("単位"), selection: $units) {
                        ForEach(UnitSystem.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }

                Section(L10n.text("ワークアウト")) {
                    Toggle(L10n.text("音声ガイド"), isOn: $voiceEnabled)
                    if HealthKitService.shared.isAvailable {
                        Toggle(L10n.text("ヘルスケアに保存"), isOn: $saveToHealth)
                            .onChange(of: saveToHealth) { _, on in
                                if on { Task { try? await HealthKitService.shared.requestAuthorization() } }
                            }
                    }
                }

                if HealthKitService.shared.isAvailable {
                    Section {
                        let pending = store.records.filter { !$0.savedToHealth }.count
                        Button {
                            Task { await saveHistoryToHealth() }
                        } label: {
                            HStack {
                                Label(L10n.format("未保存の履歴をヘルスケアへ保存（%@ 件）", String(describing: pending)), systemImage: "heart")
                                if exporting { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(pending == 0 || restoring || exporting)
                        Button {
                            Task { await restoreFromHealth() }
                        } label: {
                            HStack {
                                Label(L10n.text("ヘルスケアから履歴を復元"), systemImage: "arrow.clockwise")
                                if restoring { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(restoring || exporting)
                    } header: {
                        Text(L10n.text("履歴の復元"))
                    } footer: {
                        Text(L10n.text("ヘルスケアへ保存済みの記録は、アプリを再インストールした後に読み戻せます。保存していない記録は復元できません。ワークアウト・距離・アクティブエネルギーの読み取りを許可してください。以前のバージョンの記録は概要のみ復元される場合があります。アプリ内の履歴を削除しても、ヘルスケアの記録は残ります。"))
                    }
                }

                Section(L10n.text("アプリについて")) {
                    NavigationLink(L10n.text("プライバシーポリシー")) { AppInformationView(page: .privacy) }
                    NavigationLink(L10n.text("サポート・使い方")) { AppInformationView(page: .support) }
                    LabeledContent(L10n.text("バージョン"), value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }

                Section(L10n.text("計算方法")) {
                    Text(L10n.text("GPS が使えないトレッドミルでは、本体に設定した速度と傾斜から計算します。速度や傾斜を変えたら、アプリでも同じ値に合わせてください。\n\n距離 = 速度 × 時間（区間ごとに積算）\n\n消費カロリーは ACSM（アメリカスポーツ医学会）の代謝計算式で求めます。\n歩行: VO₂ = 0.1×速度 + 1.8×速度×傾斜 + 3.5\n走行: VO₂ = 0.2×速度 + 0.9×速度×傾斜 + 3.5\n（VO₂: mL/kg/分、速度: m/分、傾斜: 小数）\n酸素 1 L ≈ 5 kcal として体重を掛けます。「運動分」は安静時（3.5）を除いた値で、ヘルスケアのアクティブエネルギーに相当します。\n\n手すりにつかまると実際の消費は少なくなります。"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .sportForm()
            .navigationTitle(L10n.text("設定"))
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") {}
            }
        }
    }

    private func loadFromHealth() async {
        do {
            try await HealthKitService.shared.requestAuthorization()
            let weight = try await HealthKitService.shared.latestWeightKg()
            let height = try await HealthKitService.shared.latestHeightCm()
            if let weight { weightKg = (weight * 2).rounded() / 2 }
            if let height { heightCm = height.rounded() }
            message = weight == nil && height == nil ? L10n.text("ヘルスケアに体重・身長のデータがありません。") : L10n.text("ヘルスケアから読み込みました。")
        } catch {
            message = error.localizedDescription
        }
    }

    private func restoreFromHealth() async {
        guard !restoring, !exporting else { return }
        restoring = true
        defer { restoring = false }
        do {
            let result = try await HealthKitService.shared.restoreWorkouts()
            guard !result.records.isEmpty else {
                message = L10n.text("復元できる記録がありません。ヘルスケアでワークアウト・歩行＋走行距離・アクティブエネルギーの読み取り許可を確認してください。別の端末からの記録は、ヘルスケアの同期が完了してから再度お試しください。")
                return
            }
            let added = try store.importHealthRecords(result.records)
            var report = L10n.format("%@ 件の履歴を復元しました。既存の記録は重複させません。", String(describing: added))
            if result.summaryOnlyCount > 0 {
                report += L10n.format("\n%@ 件は概要のみ取得できました。速度・傾斜・体重など、不明な情報は推測しません。", String(describing: result.summaryOnlyCount))
            }
            if result.skippedCount > 0 {
                report += L10n.format("\n必要なデータがない %@ 件は復元できませんでした。", String(describing: result.skippedCount))
            }
            message = report
        } catch {
            message = L10n.format("履歴を復元できませんでした。\n%@", String(describing: error.localizedDescription))
        }
    }

    private func saveHistoryToHealth() async {
        guard !exporting, !restoring else { return }
        exporting = true
        defer { exporting = false }
        let pending = store.records.filter { !$0.savedToHealth }
        var saved = 0
        do {
            for var record in pending {
                try await HealthKitService.shared.save(record)
                record.savedToHealth = true
                try store.importHealthRecords([record])
                saved += 1
            }
            message = L10n.format("%@ 件の履歴をヘルスケアへ保存しました。", String(describing: saved))
        } catch {
            message = L10n.format("%@ 件を保存しました。残りの記録を保存できませんでした。\n%@\nアプリ内の履歴は残っています。", String(describing: saved), String(describing: error.localizedDescription))
        }
    }
}
