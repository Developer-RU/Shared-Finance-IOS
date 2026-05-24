import Foundation
import Combine

extension Notification.Name {
    static let sharedFinanceDataDidChange = Notification.Name("sharedFinanceDataDidChange")
}

@MainActor
final class SyncService {
    private let repository: SharedFinanceRepository
    private let bleManager: BLEManager
    private let errorLogger: ErrorLogger

    init(repository: SharedFinanceRepository, bleManager: BLEManager, errorLogger: ErrorLogger) {
        self.repository = repository
        self.bleManager = bleManager
        self.errorLogger = errorLogger
        self.bleManager.setResponsePayloadProvider { [weak self] inbound in
            guard let self else { return Data() }
            if !inbound.isEmpty {
                do {
                    let remote = try JSONDecoder.shared.decode(SyncPayload.self, from: inbound)
                    self.repository.importPayload(remote)
                    NotificationCenter.default.post(name: .sharedFinanceDataDidChange, object: nil)
                    self.errorLogger.log(
                        "Imported BLE inbound payload: projects=\(remote.projects.count), participants=\(remote.participants.count), expenses=\(remote.expenses.count), history=\(remote.history.count), syncLogs=\(remote.syncLogs.count)"
                    )
                } catch {
                    self.errorLogger.log(error, context: "BLE inbound import")
                }
            }
            return (try? JSONEncoder.pretty.encode(self.repository.exportPayload())) ?? Data()
        }
    }

    var discoveredDevices: [BLEDevice] { bleManager.discoveredDevices }
    var discoveredDevicesPublisher: Published<[BLEDevice]>.Publisher { bleManager.$discoveredDevices }
    var connectedDevicePublisher: Published<BLEDevice?>.Publisher { bleManager.$connectedDevice }
    var transferProgressPublisher: Published<Double>.Publisher { bleManager.$transferProgress }

    func startScan() {
        bleManager.startScan()
    }

    func stopScan() {
        bleManager.stopScan()
    }

    func connect(device: BLEDevice) {
        bleManager.connect(device)
    }

    func disconnect() {
        bleManager.disconnect()
    }

    func fetchProjects() -> [Project] {
        repository.fetchProjects()
    }

    func syncNow(selectedProjectIDs: Set<UUID>? = nil) async -> String {
        guard let connected = bleManager.connectedDevice else {
            repository.appendSyncLog(makeSyncLog(deviceName: "Unknown", result: .failed, changedRecordsCount: 0))
            return "sync_status_no_device"
        }

        let local = filterPayload(repository.exportPayload(), selectedProjectIDs: selectedProjectIDs)
        let remote: SyncPayload
        do {
            let outbound = try JSONEncoder.pretty.encode(local)
            let inbound = try await bleManager.transfer(payload: outbound)
            let decodedRemote = try JSONDecoder.shared.decode(SyncPayload.self, from: inbound)
            remote = filterPayload(decodedRemote, selectedProjectIDs: selectedProjectIDs)
        } catch {
            repository.appendSyncLog(makeSyncLog(deviceName: connected.name, result: .failed, changedRecordsCount: 0))
            errorLogger.log(error, context: "BLE transfer")
            return "sync_status_error_transfer"
        }

        repository.importPayload(remote)
        NotificationCenter.default.post(name: .sharedFinanceDataDidChange, object: nil)
        repository.appendSyncLog(makeSyncLog(deviceName: connected.name, result: .success, changedRecordsCount: remote.expenses.count))
        errorLogger.log("Imported remote payload: projects=\(remote.projects.count), participants=\(remote.participants.count), expenses=\(remote.expenses.count), history=\(remote.history.count), syncLogs=\(remote.syncLogs.count)")
        return "sync_status_finished"
    }

    private func filterPayload(_ payload: SyncPayload, selectedProjectIDs: Set<UUID>?) -> SyncPayload {
        guard let selectedProjectIDs, !selectedProjectIDs.isEmpty else {
            return payload
        }

        let filteredProjects = payload.projects.filter { selectedProjectIDs.contains($0.id) }
        let filteredProjectIDs = Set(filteredProjects.map(\.id))
        let filteredExpenses = payload.expenses.filter { filteredProjectIDs.contains($0.projectID) }
        let participantIDs = Set(filteredExpenses.map(\.participantID) + filteredProjects.flatMap(\.participantIDs))
        let filteredParticipants = payload.participants.filter { participantIDs.contains($0.id) }

        return SyncPayload(
            databaseVersion: payload.databaseVersion,
            projects: filteredProjects,
            participants: filteredParticipants,
            expenses: filteredExpenses,
            history: payload.history,
            syncLogs: payload.syncLogs
        )
    }

    private func makeSyncLog(deviceName: String, result: SyncResult, changedRecordsCount: Int) -> SyncLogEntry {
        let telemetry = bleManager.lastTransferTelemetry
        return SyncLogEntry(
            deviceName: deviceName,
            result: result,
            changedRecordsCount: changedRecordsCount,
            bleLogicalPacketCount: telemetry?.logicalPacketCount,
            bleRetryCount: telemetry?.retryCount,
            bleTimeoutCount: telemetry?.timeoutCount,
            bleAverageRetryDelayNs: telemetry?.averageRetryDelayNs,
            bleMaxRetryDelayNs: telemetry?.maxRetryDelayNs,
            bleJitterPercent: telemetry?.jitterPercent
        )
    }
}
