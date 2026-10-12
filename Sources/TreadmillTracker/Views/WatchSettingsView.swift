import SwiftUI
import TreadmillKit

struct WatchSettingsView: View {
    @AppStorage(HeartRateSettings.storageKey) private var data = Data()
    @AppStorage("linkWatchWorkout") private var linkWatch = false
    @State private var settings = HeartRateSettings()
    var body: some View {
        Form {
            Section { NavigationLink(L10n.text("Watch連携の使い方")) { AppInformationView(page: .support) } }
            Section { Toggle(L10n.text("iPhoneの運動とWatchを連動"), isOn: $linkWatch) }
            Section {
                Stepper(value: $settings.lower, in: 40...(settings.upper - 5), step: 5) {
                    LabeledContent(L10n.text("目標の下限"), value: String(format: "%.0f BPM", settings.lower))
                }
                Stepper(value: $settings.upper, in: (settings.lower + 5)...220, step: 5) {
                    LabeledContent(L10n.text("目標の上限"), value: String(format: "%.0f BPM", settings.upper))
                }
            } header: { Text(L10n.text("目標心拍数")) } footer: {
                Text(L10n.text("初期値は仮の範囲です。年齢・体力・服薬によって適切な負荷は異なります。自分に合う範囲へ調整し、体調や体感を優先してください。"))
            }
            Section {
                Button(L10n.text("この目標範囲をWatchで使う")) { settings.configured = true; linkWatch = true; WatchBridge.shared.publishSettings(settings) }
                Toggle(L10n.text("振動でアドバイス"), isOn: $settings.haptics)
                Toggle(L10n.text("Watchの運動をヘルスケアに保存"), isOn: $settings.saveToHealth)
            } footer: { Text(L10n.text("設定はWatchに接続できたときに反映され、次の運動から使われます。心拍ガイドはWatch単体でも動きます。")) }
            Section {
                Text(L10n.text("最初の2分はウォームアップ。15秒の平均心拍を使い、範囲外の状態が15秒続いたら案内します。振動の間隔は最低60秒です。"))
                Text(L10n.text("胸の痛み、めまい、強い息苦しさがある場合は運動を中止してください。表示は運動強度の目安で、医療判断や減量効果の保証ではありません。"))
            }
        }
        .navigationTitle(L10n.text("Apple Watch 心拍ガイド"))
        .onAppear { if let value = try? JSONDecoder().decode(HeartRateSettings.self, from: data), value.isValid { settings = value } }
        .onChange(of: settings) { _, value in
            guard value.isValid, let encoded = try? JSONEncoder().encode(value) else { return }
            data = encoded; WatchBridge.shared.publishSettings(value)
        }
    }
}
