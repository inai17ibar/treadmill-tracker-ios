import Foundation
import TreadmillKit

/// @AppStorage keys shared by the views.
enum SettingsKey {
    static let weightKg = "weightKg"
    static let heightCm = "heightCm"
    static let units = "units"
    static let voiceEnabled = "voiceEnabled"
    static let saveToHealth = "saveToHealth"
    static let startSpeedKmh = "startSpeedKmh"
    static let startInclinePercent = "startInclinePercent"
    static let gaitMode = "gaitMode"
}

/// What the user picked on the home screen.
struct WorkoutSetup {
    var program: WorkoutProgram?
    var speedKmh: Double
    var inclinePercent: Double
    var gaitMode: GaitMode
    var goal: WorkoutGoal
}

enum GoalKind: String, CaseIterable, Identifiable {
    case none, duration, distance, kcal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "なし"
        case .duration: return "時間"
        case .distance: return "距離"
        case .kcal: return "カロリー"
        }
    }
}
