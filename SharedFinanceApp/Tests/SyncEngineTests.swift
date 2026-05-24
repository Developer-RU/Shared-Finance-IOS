import XCTest
@testable import SharedFinanceApp

final class SyncEngineTests: XCTestCase {
    func testRemoteHigherVersionWins() {
        let errorLogger = ErrorLogger()
        let engine = SyncEngine(errorLogger: errorLogger)

        let id = UUID()
        let local = Project(id: id, title: "Local", details: "A", recordVersion: 1, updatedAt: Date(timeIntervalSince1970: 100))
        let remote = Project(id: id, title: "Remote", details: "A", recordVersion: 2, updatedAt: Date(timeIntervalSince1970: 200))

        let delta = engine.detectConflicts(
            local: SyncPayload(projects: [local], participants: [], expenses: [], history: [], syncLogs: []),
            remote: SyncPayload(projects: [remote], participants: [], expenses: [], history: [], syncLogs: [])
        )

        XCTAssertEqual(delta.conflicts.count, 1)
    }

    func testBLEChunkingProducesMultipleChunks() {
        let data = Data(repeating: 7, count: 500)
        let chunks = BLEProtocol.chunk(data)

        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertEqual(chunks.flatMap { $0 }.count, data.count)
    }
}
