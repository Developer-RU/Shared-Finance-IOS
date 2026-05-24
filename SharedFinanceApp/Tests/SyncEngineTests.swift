import XCTest
@testable import SharedFinanceApp

final class SyncEngineTests: XCTestCase {
    func testBLEChunkingProducesMultipleChunks() {
        let data = Data(repeating: 7, count: 500)
        let chunks = BLEProtocol.chunk(data)

        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertEqual(chunks.flatMap { $0 }.count, data.count)
    }
}
