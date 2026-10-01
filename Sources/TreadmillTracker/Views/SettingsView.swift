import SwiftUI
import TreadmillKit

struct SettingsView: View {
    @AppStorage(SettingsKey.weightKg) private var weightKg = 60.0
    @AppStorage(SettingsKey.heightCm) private var heightCm = 170.0
    @AppStorage(SettingsKey.units) private var units: UnitSystem = .metric
    @AppStorage(SettingsKey.voiceEnabled) private var voiceEnabled = true
    @AppStorage(SettingsKey.saveToHealth) private var saveToHealth = true
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $weightKg, in: 25...250, step: 0.5) {
                        LabeledContent("体重", value: String(format: "%.1f kg", weightKg))
                    }
                    Stepper(value: $heightCm, in: 100...230, step: 1) {
                        LabeledContent("身長", value: String(format: "%.0f cm", heightCm))
                    }
                    if HealthKitService.shared.isAvailable {
                        Button("ヘルスケアから読み込む") { Task { await loadFromHealth() } }
                    }
                } header: {
                    Text("プロフィール")
                } footer: {
                    Text("消費カロリーは体重に比例します。正確な体重を設定してください。")
                }

                Section("表示") {
                    Picker("単位", selection: $units) {
                        ForEach(UnitSystem.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }

                Section("ワークアウト") {
                    Toggle("音声ガイド", isOn: $voiceEnabled)
                    if HealthKitService.shared.isAvailable {
                        Toggle("ヘルスケアに保存", isOn: $saveToHealth)
                            .onChange(of: saveToHealth) { _, on in
                                if on { Task { try? await HealthKitService.shared.requestAuthorization() } }
                            }
                    }
                }

                Section("計算方法") {
                    Text("""
                    GPS が使えないトレッドミルでは、本体に設定した速度と傾斜から計算します。速度や傾斜を変えたら、アプリでも同じ値に合わせてください。

                    距離 = 速度 × 時間（区間ごとに積算）

                    消費カロリーは ACSM（アメリカスポーツ医学会）の代謝計算式で求めます。
                    歩行: VO₂ = 0.1×速度 + 1.8×速度×傾斜 + 3.5
                    走行: VO₂ = 0.2×速度 + 0.9×速度×傾斜 + 3.5
                    （VO₂: mL/kg/分、速度: m/分、傾斜: 小数）
                    酸素 1 L ≈ 5 kcal として体重を掛けます。「運動分」は安静時（3.5）を除いた値で、ヘルスケアのアクティブエネルギーに相当します。

                    手すりにつかまると実際の消費は少なくなります。
                    """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
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
            message = weight == nil && height == nil ? "ヘルスケアに体重・身長のデータがありません。" : "ヘルスケアから読み込みました。"
        } catch {
            message = error.localizedDescription
        }
    }
}
