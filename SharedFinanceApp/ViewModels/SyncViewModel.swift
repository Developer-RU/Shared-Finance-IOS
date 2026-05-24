import Foundation
import Combine

@MainActor
final class SyncViewModel: ObservableObject {
    enum State {
        case idle
        case scanning
        case connecting(String)
        case syncing(Double)
        case completed
        case failed(String)
    }

    @Published var devices: [BLEDevice] = []
    @Published var connectedDevice: BLEDevice?
    @Published var conflicts: [SyncConflict] = []
    @Published var availableProjects: [Project] = []
    @Published var selectedProjectIDs: Set<UUID> = []
    @Published var state: State = .idle
    @Published var statusMessage = ""
    @Published var progress: Double = 0

    private let syncService: SyncService
    private(set) var decisions: [UUID: Bool] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(syncService: SyncService) {
        self.syncService = syncService
        syncService.discoveredDevicesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.devices = devices
            }
            .store(in: &cancellables)

        syncService.connectedDevicePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard let self else { return }
                self.connectedDevice = connected
                if let connected {
                    self.statusMessage = "sync_status_connected_to"
                    if case .connecting = self.state {
                        self.state = .idle
                    }
                    if self.devices.contains(where: { $0.id == connected.id }) == false {
                        self.devices.append(connected)
                    }
                } else {
                    self.connectedDevice = nil
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .sharedFinanceDataDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshProjectSelection()
            }
            .store(in: &cancellables)

        refreshProjectSelection()
    }

    var allConflictsDecided: Bool {
        !conflicts.isEmpty && conflicts.allSatisfy { decisions[$0.id] != nil }
    }

    var conflictDecisionProgressText: String {
        "\(decisions.count)/\(conflicts.count)"
    }

    func loadDevices() {
        devices = syncService.discoveredDevices
    }

    func startScan() {
        state = .scanning
        syncService.startScan()
        statusMessage = "sync_status_scanning_started"
    }

    func stopScan() {
        syncService.stopScan()
        devices = []
        state = .idle
    }

    func connect(device: BLEDevice) {
        state = .connecting(device.name)
        syncService.connect(device: device)
    }

    func toggleDeviceConnection(_ device: BLEDevice) {
        if connectedDevice?.id == device.id {
            syncService.disconnect()
            state = .idle
        } else {
            connect(device: device)
        }
    }

    func syncNow() async {
        state = .syncing(0.5)
        let projectIDs = selectedProjectIDs.isEmpty ? nil : selectedProjectIDs
        let result = await syncService.syncNow(selectedProjectIDs: projectIDs)
        conflicts = result.conflicts
        statusMessage = result.status
        progress = 1
        state = .completed
    }

    func refreshProjectSelection() {
        let projects = syncService.fetchProjects().sorted { $0.updatedAt > $1.updatedAt }
        availableProjects = projects
        if selectedProjectIDs.isEmpty {
            selectedProjectIDs = Set(projects.map(\.id))
        } else {
            let validIDs = Set(projects.map(\.id))
            selectedProjectIDs = selectedProjectIDs.intersection(validIDs)
            if selectedProjectIDs.isEmpty {
                selectedProjectIDs = validIDs
            }
        }
    }

    func toggleProjectSelection(_ projectID: UUID) {
        if selectedProjectIDs.contains(projectID) {
            selectedProjectIDs.remove(projectID)
        } else {
            selectedProjectIDs.insert(projectID)
        }
    }

    func selectAllProjects() {
        selectedProjectIDs = Set(availableProjects.map(\.id))
    }

    func clearSelectedProjects() {
        selectedProjectIDs.removeAll()
    }

    func acceptConflict(_ conflict: SyncConflict) {
        decisions[conflict.id] = true
    }

    func rejectConflict(_ conflict: SyncConflict) {
        decisions[conflict.id] = false
    }

    func acceptAllConflicts() {
        conflicts.forEach { decisions[$0.id] = true }
    }

    func keepAllLocalConflicts() {
        conflicts.forEach { decisions[$0.id] = false }
    }

    func autoSelectByVersionRule() {
        conflicts.forEach { conflict in
            decisions[conflict.id] = conflict.remoteRecordVersion >= conflict.localRecordVersion
        }
    }

    func isUndecided(_ conflict: SyncConflict) -> Bool {
        decisions[conflict.id] == nil
    }

    func decisionText(for conflict: SyncConflict) -> String {
        guard let decision = decisions[conflict.id] else {
            return "sync_decision_not_selected"
        }
        return decision ? "sync_decision_accept_remote" : "sync_decision_keep_local"
    }

    func applyConflictDecisions() async {
        syncService.apply(decisions: decisions, conflicts: conflicts)
        statusMessage = "sync_status_decisions_applied"
        decisions.removeAll()
        conflicts.removeAll()
    }
}
