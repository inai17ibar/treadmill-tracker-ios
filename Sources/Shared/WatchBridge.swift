import Foundation
import WatchConnectivity
import TreadmillKit

/// Settings are latest-state messages. Finished records use queued background delivery.
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()
    var onRecords: (([WorkoutRecord]) throws -> Void)?
    var onLinkedWorkout: ((LinkedWorkout) -> Void)?
    var onHeart: ((UUID, HeartRatePoint) -> Void)?
    private var linked: LinkedWorkout?
    var onSettings: ((HeartRateSettings) -> Void)?
    private override init() { super.init() }
    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    func publishSettings(_ settings: HeartRateSettings) {
        guard settings.isValid, WCSession.default.activationState == .activated,
              let data = try? JSONEncoder().encode(settings) else { return }
        var context = WCSession.default.applicationContext
        context["heartSettings"] = data
        try? WCSession.default.updateApplicationContext(context)
    }
    func publishWorkout(_ workout: LinkedWorkout) {
        guard let data = try? JSONEncoder().encode(workout) else { return }
        UserDefaults.standard.set(data, forKey: "linkedWorkout")
        guard WCSession.default.activationState == .activated else { return }
        var context = WCSession.default.applicationContext
        context["linkedWorkout"] = data
        try? WCSession.default.updateApplicationContext(context)
        if WCSession.default.isReachable { WCSession.default.sendMessage(["linkedWorkout": data], replyHandler: nil, errorHandler: nil) }
    }
    func sendHeart(id: UUID, point: HeartRatePoint) {
        guard WCSession.default.isReachable, let data = try? JSONEncoder().encode(point) else { return }
        WCSession.default.sendMessage(["heartID": id.uuidString, "heart": data], replyHandler: nil, errorHandler: nil)
    }
    func replayContext() { receive(WCSession.default.receivedApplicationContext) }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { receive(message) }
    private var outbox: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("WatchOutbox", isDirectory: true)
    }
    func send(_ records: [WorkoutRecord]) {
        do {
            try FileManager.default.createDirectory(at: outbox, withIntermediateDirectories: true)
            for record in records {
                try WorkoutRecord.encodeList([record]).write(to: outbox.appendingPathComponent(record.id.uuidString + ".json"), options: .atomic)
            }
            flushOutbox()
        } catch { print("Watch outbox: \(error)") }
    }
    private func flushOutbox() {
        guard WCSession.default.activationState == .activated else { return }
        let queued = Set(WCSession.default.outstandingFileTransfers.map { $0.file.fileURL.lastPathComponent })
        for file in (try? FileManager.default.contentsOfDirectory(at: outbox, includingPropertiesForKeys: nil)) ?? [] where !queued.contains(file.lastPathComponent) {
            WCSession.default.transferFile(file, metadata: ["watchRecord": true])
        }
    }
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?["watchRecord"] as? Bool == true,
              let data = try? Data(contentsOf: file.fileURL), (try? WorkoutRecord.decodeList(data)) != nil else { return }
        // The system's incoming file is temporary; copy it before returning from the delegate.
        let inbox = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("WatchInbox", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
            try data.write(to: inbox.appendingPathComponent(UUID().uuidString + ".json"), options: .atomic)
            DispatchQueue.main.async { self.importPendingRecords() }
        } catch { print("Watch inbox: \(error)") }
    }
    func importPendingRecords() {
        guard let onRecords else { return }
        let inbox = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("WatchInbox", isDirectory: true)
        for file in (try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)) ?? [] {
            do {
                let records = try WorkoutRecord.decodeList(Data(contentsOf: file))
                try onRecords(records)
                try FileManager.default.removeItem(at: file)
            } catch { print("Watch inbox import: \(error)") }
        }
    }
    func session(_ session: WCSession, didFinish transfer: WCSessionFileTransfer, error: Error?) {
        if error == nil { try? FileManager.default.removeItem(at: transfer.file.fileURL) }
    }
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        receive(session.receivedApplicationContext)
        #if os(iOS)
        let settings = UserDefaults.standard.data(forKey: HeartRateSettings.storageKey)
            .flatMap { try? JSONDecoder().decode(HeartRateSettings.self, from: $0) } ?? HeartRateSettings()
        publishSettings(settings)
        if let data = UserDefaults.standard.data(forKey: "linkedWorkout"), let workout = try? JSONDecoder().decode(LinkedWorkout.self, from: data) { publishWorkout(workout) }
        #else
        flushOutbox()
        #endif
    }
    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) { receive(context) }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) { receive(userInfo) }
    private func receive(_ values: [String: Any]) {
        if let data = values["linkedWorkout"] as? Data, let workout = try? JSONDecoder().decode(LinkedWorkout.self, from: data) {
            DispatchQueue.main.async {
                guard workout.canReplace(self.linked, now: Date()) else { return }
                self.linked = workout
                self.onLinkedWorkout?(workout)
            }
        }
        if let value = values["heartID"] as? String, let id = UUID(uuidString: value),
           let data = values["heart"] as? Data, let point = try? JSONDecoder().decode(HeartRatePoint.self, from: data) {
            DispatchQueue.main.async { self.onHeart?(id, point) }
        }
        if let data = values["heartSettings"] as? Data,
           let settings = try? JSONDecoder().decode(HeartRateSettings.self, from: data), settings.isValid {
            UserDefaults.standard.set(data, forKey: HeartRateSettings.storageKey)
            DispatchQueue.main.async { self.onSettings?(settings) }
        }
        if let data = values["watchRecords"] as? Data, let records = try? WorkoutRecord.decodeList(data) {
            DispatchQueue.main.async { try? self.onRecords?(records) }
        }
    }
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
