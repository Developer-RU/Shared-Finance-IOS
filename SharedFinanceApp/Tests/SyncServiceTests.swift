import XCTest
@testable import SharedFinanceApp

final class SyncServiceTests: XCTestCase {
    @MainActor
    func testSyncFailsWithoutConnectedDevice() async {
        let logger = ErrorLogger()
        let db = DatabaseManager(errorLogger: logger)
        let repo = LocalSharedFinanceRepository(databaseManager: db, errorLogger: logger)
        let ble = BLEManager(errorLogger: logger)
        let engine = SyncEngine(errorLogger: logger)
        let service = SyncService(repository: repo, bleManager: ble, syncEngine: engine, errorLogger: logger)

        let result = await service.syncNow()

        XCTAssertEqual(result.status, "sync_status_no_device")
        XCTAssertTrue(result.conflicts.isEmpty)
    }

    @MainActor
    func testSyncStoresBleTelemetryInSyncLog() async {
        let logger = ErrorLogger()
        let db = DatabaseManager(errorLogger: logger)
        let repo = LocalSharedFinanceRepository(databaseManager: db, errorLogger: logger)
        let ble = BLEManager(errorLogger: logger)
        let engine = SyncEngine(errorLogger: logger)
        let service = SyncService(repository: repo, bleManager: ble, syncEngine: engine, errorLogger: logger)

        ble.connect(BLEDevice(name: "Demo BLE Device", signalStrength: -42))

        let result = await service.syncNow()
        let logs = repo.fetchSyncLogs()
        let successLog = logs.first(where: { $0.result == .success })

        XCTAssertEqual(result.status, "sync_status_finished")
        XCTAssertNotNil(successLog)
        XCTAssertNotNil(successLog?.bleLogicalPacketCount)
        XCTAssertNotNil(successLog?.bleRetryCount)
        XCTAssertNotNil(successLog?.bleTimeoutCount)
        XCTAssertNotNil(successLog?.bleAverageRetryDelayNs)
        XCTAssertNotNil(successLog?.bleMaxRetryDelayNs)
        XCTAssertNotNil(successLog?.bleJitterPercent)
    }
}
