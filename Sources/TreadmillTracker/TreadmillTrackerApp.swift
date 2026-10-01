import SwiftUI

@main
struct TreadmillTrackerApp: App {
    @State private var store = WorkoutStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView()
                    .tabItem { Label("ワークアウト", systemImage: "figure.run.treadmill") }
                HistoryView()
                    .tabItem { Label("履歴", systemImage: "list.bullet.rectangle") }
                SettingsView()
                    .tabItem { Label("設定", systemImage: "gearshape") }
            }
            .environment(store)
        }
    }
}
