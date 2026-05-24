import Foundation
import Combine

@MainActor
final class SyncViewModel: ObservableObject {
    private static let scanDurationNs: UInt64 = 10_000_000_000

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
    @Published var availableProjects: [Project] = []
    @Published var selectedProjectIDs: Set<UUID> = []
    @Published var state: State = .idle
    @Published var statusMessage = ""
    @Published var progress: Double = 0

    private let syncService: SyncService
    private var cancellables = Set<AnyCancellable>()
    private var scanAutoStopTask: Task<Void, Never>?

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

        syncService.transferProgressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transferProgress in
                guard let self else { return }
                guard case .syncing = self.state else { return }
                self.progress = transferProgress
                self.state = .syncing(transferProgress)
                if transferProgress >= 0.85 && transferProgress < 1 {
                    self.statusMessage = "sync_status_waiting_response"
                } else if transferProgress > 0 && transferProgress < 0.85 {
                    self.statusMessage = "sync_status_transferring"
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

    func loadDevices() {
        devices = syncService.discoveredDevices
    }

    func startScan() {
        scanAutoStopTask?.cancel()
        devices = []
        state = .scanning
        syncService.startScan()
        statusMessage = "sync_status_scanning_started"

        scanAutoStopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.scanDurationNs)
            await MainActor.run {
                guard let self else { return }
                if case .scanning = self.state {
                    self.stopScan()
                }
            }
        }
    }

    func stopScan() {
        scanAutoStopTask?.cancel()
        scanAutoStopTask = nil
        syncService.stopScan()
        state = .idle
    }

    func connect(device: BLEDevice) {
        state = .connecting(device.name)
        statusMessage = "sync_status_connecting"
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
        progress = 0.01
        state = .syncing(progress)
        statusMessage = "sync_status_transferring"
        let projectIDs = selectedProjectIDs.isEmpty ? nil : selectedProjectIDs
        statusMessage = await syncService.syncNow(selectedProjectIDs: projectIDs)
        if statusMessage == "sync_status_finished" {
            progress = 1
            state = .completed
        } else {
            progress = 0
            state = .failed(statusMessage)
        }
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
}
