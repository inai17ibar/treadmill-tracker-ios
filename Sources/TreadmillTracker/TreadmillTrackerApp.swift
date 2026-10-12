import TreadmillKit
import SwiftUI

@main
struct TreadmillTrackerApp: App {
    @State private var store = WorkoutStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView()
                    .tabItem { Label(L10n.text("ワークアウト"), systemImage: "figure.run.treadmill") }
                HistoryView()
                    .tabItem { Label(L10n.text("履歴"), systemImage: "list.bullet.rectangle") }
                SettingsView()
                    .tabItem { Label(L10n.text("設定"), systemImage: "gearshape") }
            }
            .environment(store)
            .tint(Theme.lime)
            .foregroundStyle(Theme.text)
            .preferredColorScheme(.dark)
        }
    }
}
