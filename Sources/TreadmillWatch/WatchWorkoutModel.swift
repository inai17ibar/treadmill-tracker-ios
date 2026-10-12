import SwiftUI
import HealthKit
import WatchKit
import TreadmillKit

@MainActor
final class WatchWorkoutModel: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    static let shared = WatchWorkoutModel()
    @Published var linkedToPhone = false
    private var latestLinked: LinkedWorkout?
    private var stoppedLinkedID: UUID?
    @Published var settings = HeartRateSettings()
    @Published var running = false
    @Published var paused = false
    @Published var finishing = false
    @Published var bpm: Double?
    @Published var elapsed: Double = 0
    @Published var zone: HeartRateGuide.Zone = .waiting
    @Published var message: String?
    private let health = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var guide = HeartRateGuide()
    private var samples: [HeartRatePoint] = []
    private var timer: Timer?
    private var start = Date()
    private var id = UUID()
    private var gait: Gait = .walk
    private var workoutSettings = HeartRateSettings()

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: HeartRateSettings.storageKey), let value = try? JSONDecoder().decode(HeartRateSettings.self, from: data), value.isValid { settings = value }
        WatchBridge.shared.onSettings = { [weak self] value in self?.settings = value }
        WatchBridge.shared.onLinkedWorkout = { [weak self] command in
            self?.latestLinked = command
            Task { await self?.applyLinkedCommand() }
        }
        WatchBridge.shared.activate()
    }
    func begin(run: Bool, linked: LinkedWorkout? = nil) async {
        guard !running, !finishing else { return }
        guard settings.configured else { message = L10n.text("iPhoneで目標心拍数を設定してください"); return }
        finishing = true
        defer { finishing = false }
        do {
            guard HKHealthStore.isHealthDataAvailable() else { throw WatchError.unavailable }
            try await health.requestAuthorization(toShare: [.workoutType(), HKQuantityType(.activeEnergyBurned), HKQuantityType(.distanceWalkingRunning)],
                read: [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned), HKQuantityType(.distanceWalkingRunning)])
            let config = HKWorkoutConfiguration()
            config.activityType = run ? .running : .walking
            config.locationType = .indoor
            let newSession = try HKWorkoutSession(healthStore: health, configuration: config)
            let newBuilder = newSession.associatedWorkoutBuilder()
            newBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: health, workoutConfiguration: config)
            newSession.delegate = self; newBuilder.delegate = self
            session = newSession; builder = newBuilder
            gait = run ? .run : .walk; workoutSettings = settings
            id = linked?.id ?? UUID(); linkedToPhone = linked != nil; start = Date(); samples = []; guide = HeartRateGuide(); bpm = nil; elapsed = 0; paused = false
            newSession.startActivity(with: start)
            try await newBuilder.beginCollection(at: start)
            running = true
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        } catch { session?.end(); builder?.discardWorkout(); session = nil; builder = nil; message = error.localizedDescription }
    }
    func handlePhoneLaunch() { WatchBridge.shared.replayContext() }
    private func applyLinkedCommand() async {
        guard let command = latestLinked, !finishing, command.id != stoppedLinkedID else { return }
        if command.state == .finished || command.state == .cancelled {
            guard running, linkedToPhone, id == command.id else { return }
            if command.state == .cancelled {
                timer?.invalidate(); timer = nil; running = false
                session?.end(); builder?.discardWorkout(); session = nil; builder = nil
            } else { await finish() }
            return
        }
        if !running {
            await begin(run: command.running, linked: command)
            if running { await applyLinkedCommand() }
            return
        }
        guard linkedToPhone, id == command.id else {
            message = L10n.text("別の運動を計測中です。Watchの運動を終了してからiPhoneで開始してください。")
            return
        }
        if command.state == .paused && !paused { session?.pause(); paused = true }
        if command.state == .running && paused { session?.resume(); paused = false }
    }
    func togglePause() { guard !linkedToPhone else { return }; paused ? session?.resume() : session?.pause() }
    private func tick() {
        elapsed = builder?.elapsedTime ?? elapsed
        let result = guide.evaluate(now: Date(), activeSeconds: elapsed, paused: paused, settings: workoutSettings)
        zone = result.0
        if zone == .waiting { bpm = nil }
        if result.1 { WKInterfaceDevice.current().play(zone == .high ? .directionDown : .directionUp) }
    }
    func finish() async {
        guard running, !finishing, let builder else { return }
        if linkedToPhone { stoppedLinkedID = id }
        finishing = true; timer?.invalidate(); timer = nil
        session?.end()
        let end = Date()
        var completed: WorkoutRecord?
        do {
            try await builder.endCollection(at: end)
            var record = WorkoutRecord(id: id, startDate: start, endDate: end, segments: [], weightKg: 0)
            record.healthSummary = HealthWorkoutSummary(duration: builder.elapsedTime,
                distanceMeters: builder.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter()) ?? 0,
                activeKcal: builder.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0,
                elevationMeters: nil, gait: gait)
            record.heartRate = samples
            record.linkedPhone = linkedToPhone ? true : nil
            completed = record
            if workoutSettings.saveToHealth && !linkedToPhone {
                var recoveryRecord = record
                recoveryRecord.heartRate = nil // Keep HealthKit metadata small; full samples travel through WatchConnectivity.
                try await builder.addMetadata([HKMetadataKeyIndoorWorkout: true,
                    HKMetadataKeySyncIdentifier: "com.inai17ibar.TreadmillTracker.\(id.uuidString).workout",
                    "com.inai17ibar.TreadmillTracker.watchRecord": String(decoding: try WorkoutRecord.encodeList([recoveryRecord]), as: UTF8.self)])
                let workout = try await builder.finishWorkout()
                record.savedToHealth = workout != nil
            } else { builder.discardWorkout() }
            persist(record)
            message = L10n.text("記録を保存しました")
        } catch {
            // Preserve a local summary even if HealthKit saving failed.
            var record = completed ?? WorkoutRecord(id: id, startDate: start, endDate: end, segments: [], weightKg: 0)
            if record.healthSummary == nil { record.healthSummary = HealthWorkoutSummary(duration: elapsed, distanceMeters: 0, activeKcal: 0, elevationMeters: nil, gait: gait) }
            record.heartRate = samples; record.linkedPhone = linkedToPhone ? true : nil; persist(record)
            message = L10n.text("Watchに保存しました。ヘルスケアへの保存に失敗しました。") + "\n" + error.localizedDescription
        }
        running = false; paused = false; finishing = false; session = nil; self.builder = nil
    }
    private func persist(_ record: WorkoutRecord) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("WatchHistory.json")
        var records = (try? Data(contentsOf: url)).flatMap { try? WorkoutRecord.decodeList($0) } ?? []
        records.removeAll { $0.id == record.id }; records.append(record)
        do { try WorkoutRecord.encodeList(records).write(to: url, options: .atomic) }
        catch { message = error.localizedDescription }
        WatchBridge.shared.send([record])
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo state: HKWorkoutSessionState, from: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            self.paused = state == .paused
            if state == .ended && self.running && !self.finishing { await self.finish() }
        }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.message = error.localizedDescription; await self.finish() }
    }
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        guard types.contains(HKQuantityType(.heartRate)), let stats = workoutBuilder.statistics(for: HKQuantityType(.heartRate)),
              let quantity = stats.mostRecentQuantity(), let interval = stats.mostRecentQuantityDateInterval() else { return }
        let point = HeartRatePoint(date: interval.end, bpm: quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
        Task { @MainActor in
            guard self.running, !self.paused, Date().timeIntervalSince(point.date) <= 20 else { return }
            self.guide.ingest(point, now: Date()); self.bpm = point.bpm
            if self.samples.last.map({ point.date > $0.date }) ?? true { self.samples.append(point) }
            if self.linkedToPhone { WatchBridge.shared.sendHeart(id: self.id, point: point) }
            self.tick()
        }
    }
    enum WatchError: LocalizedError {
        case unavailable
        var errorDescription: String? { L10n.text("ヘルスケアを利用できません") }
    }
}
