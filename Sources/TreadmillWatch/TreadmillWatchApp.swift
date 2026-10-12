import SwiftUI
import TreadmillKit
import WatchKit
import HealthKit

@main
struct TreadmillWatchApp: App {
    @WKApplicationDelegateAdaptor(WorkoutAppDelegate.self) private var delegate
    @StateObject private var model = WatchWorkoutModel.shared
    var body: some Scene {
        WindowGroup {
            NavigationStack { ScrollView {
                VStack(spacing: 12) {
                    Label("TREADMILL", systemImage: "figure.run.treadmill").font(.caption).foregroundStyle(.secondary)
                    if model.running {
                        Text(model.bpm.map { String(format: "%.0f", $0) } ?? "—").font(.system(size: 54, weight: .bold, design: .rounded))
                        Text("BPM").font(.caption).foregroundStyle(.secondary)
                        Text(coaching).font(.headline).foregroundStyle(color).multilineTextAlignment(.center)
                        Text(String(format: "%02d:%02d", Int(model.elapsed) / 60, Int(model.elapsed) % 60)).monospacedDigit()
                        if model.linkedToPhone {
                            Text(L10n.text("開始・一時停止・終了はiPhoneで操作")) .font(.footnote).foregroundStyle(.secondary)
                            Button(L10n.text("心拍測定を終了"), role: .destructive) { Task { await model.finish() } }.disabled(model.finishing)
                        } else {
                        Button(L10n.text(model.paused ? "再開" : "一時停止")) { model.togglePause() }.disabled(model.finishing)
                        Button(L10n.text("終了して保存"), role: .destructive) { Task { await model.finish() } }.disabled(model.finishing)
                        }
                    } else {
                        Image(systemName: "heart.fill").font(.largeTitle).foregroundStyle(.pink)
                        Text(L10n.text("目標心拍数"))
                        Text(String(format: "%.0f–%.0f BPM", model.settings.lower, model.settings.upper)).bold()
                        Button(L10n.text("ウォーキング")) { Task { await model.begin(run: false) } }.disabled(model.finishing)
                        Button(L10n.text("ランニング")) { Task { await model.begin(run: true) } }.disabled(model.finishing)
                        Text(L10n.text("目標範囲はiPhoneの設定で調整してください。体調や体感を優先しましょう。")) .font(.footnote).foregroundStyle(.secondary)
                    }
                    NavigationLink(L10n.text("使い方")) { WatchGuideView() }
                    if model.finishing { ProgressView() }
                }.padding(.horizontal, 6)
            }
            }
            .tint(Color(red: 0.78, green: 1, blue: 0.27))
            .alert(model.message ?? "", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) { Button("OK") { model.message = nil } }
        }
    }
    private var color: Color { model.zone == .high ? .orange : model.zone == .low ? .cyan : .green }
    private var coaching: String {
        switch model.zone {
        case .waiting: return L10n.text("心拍を確認中")
        case .warmup: return L10n.text("ゆっくり始めましょう")
        case .low: return L10n.text("余裕があれば少しペースを上げましょう")
        case .target: return L10n.text("いい調子。このペースで")
        case .high: return L10n.text("少しペースを落としましょう")
        case .paused: return L10n.text("一時停止中")
        }
    }
}

final class WorkoutAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in WatchWorkoutModel.shared.handlePhoneLaunch() }
    }
}

struct WatchGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("Watch連携の使い方")).font(.headline)
                Text(L10n.text("iPhoneで目標心拍数を設定し、連動をオンにします。Watchを装着・ロック解除して、初回は心拍の読み取りを許可してください。"))
                Text(L10n.text("iPhoneでスタートするとWatchへ開始をリクエストします。心拍が表示されたことを確認してください。一時停止・再開・終了もiPhoneから操作します。"))
                Text(L10n.text("連動中はiPhoneで保存します。Watchは心拍を後から同じ記録へ追加するため、接続が切れても2件には分かれません。Watch単体で始める場合はWatchで終了・保存してください。"))
                Text(L10n.text("心拍が出ない場合はWatchアプリを開き、装着状態・許可・接続を確認してください。体調や体感を優先し、異変を感じたら運動を中止してください。"))
            }.font(.footnote).padding()
        }
    }
}
