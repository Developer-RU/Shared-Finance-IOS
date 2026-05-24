import XCTest
@testable import SharedFinanceApp

final class SyncServiceTests: XCTestCase {
    @MainActor
    func testSyncFailsWithoutConnectedDevice() async {
        let logger = ErrorLogger()
        let db = DatabaseManager(errorLogger: logger)
        let repo = LocalSharedFinanceRepository(databaseManager: db, errorLogger: logger)
        let ble = BLEManager(errorLogger: logger)
        let service = SyncService(repository: repo, bleManager: ble, errorLogger: logger)

        let result = await service.syncNow()

        XCTAssertEqual(result, "sync_status_no_device")
    }

    @MainActor
    func testSyncStoresBleTelemetryInSyncLog() async {
        let logger = ErrorLogger()
        let db = DatabaseManager(errorLogger: logger)
        let repo = LocalSharedFinanceRepository(databaseManager: db, errorLogger: logger)
        let ble = BLEManager(errorLogger: logger)
        let service = SyncService(repository: repo, bleManager: ble, errorLogger: logger)

        let device = BLEDevice(name: "Demo BLE Device", signalStrength: -42)
        let telemetry = BLETransferTelemetry(
            logicalPacketCount: 3,
            retryCount: 1,
            timeoutCount: 0,
            averageRetryDelayNs: 10_000_000,
            maxRetryDelayNs: 10_000_000,
            jitterPercent: 0.2
        )

        ble.configureSimulatedConnectionForTesting(device: device, telemetry: telemetry) { _ in
            try JSONEncoder.pretty.encode(repo.exportPayload())
        }

        let result = await service.syncNow()
        let logs = repo.fetchSyncLogs()
        let successLog = logs.first(where: { $0.result == .success })

        XCTAssertEqual(result, "sync_status_finished")
        XCTAssertNotNil(successLog)
        XCTAssertNotNil(successLog?.bleLogicalPacketCount)
        XCTAssertNotNil(successLog?.bleRetryCount)
        XCTAssertNotNil(successLog?.bleTimeoutCount)
        XCTAssertNotNil(successLog?.bleAverageRetryDelayNs)
        XCTAssertNotNil(successLog?.bleMaxRetryDelayNs)
        XCTAssertNotNil(successLog?.bleJitterPercent)
    }
}
