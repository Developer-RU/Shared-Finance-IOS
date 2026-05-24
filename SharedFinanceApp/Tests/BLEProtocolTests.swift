import XCTest
@testable import SharedFinanceApp

final class BLEProtocolTests: XCTestCase {
    func testPacketEncodeDecodeRoundtrip() {
        let payload = Data([1, 2, 3, 4, 5])
        let encoded = BLEProtocol.encode(type: .chunk, index: 42, payload: payload)

        let decoded = BLEProtocol.decode(encoded)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.type, .chunk)
        XCTAssertEqual(decoded?.index, 42)
        XCTAssertEqual(decoded?.payload, payload)
    }

    func testRetryAttemptsFromMaxRetries() {
        XCTAssertEqual(BLEProtocol.totalAttempts(maxRetries: 0), 1)
        XCTAssertEqual(BLEProtocol.totalAttempts(maxRetries: 2), 3)
        XCTAssertEqual(BLEProtocol.totalAttempts(maxRetries: -5), 1)
    }

    func testControlIndexesDoNotCollide() {
        XCTAssertNotEqual(BLEProtocol.controlStartIndex, BLEProtocol.controlEndIndex)
        XCTAssertGreaterThan(BLEProtocol.controlStartIndex, 10)
        XCTAssertGreaterThan(BLEProtocol.controlEndIndex, BLEProtocol.controlStartIndex)
    }

    func testRetryDelayIsExponential() {
        let d1 = BLEProtocol.retryDelay(attempt: 1, baseDelayNs: 10, maxDelayNs: 1000)
        let d2 = BLEProtocol.retryDelay(attempt: 2, baseDelayNs: 10, maxDelayNs: 1000)
        let d3 = BLEProtocol.retryDelay(attempt: 3, baseDelayNs: 10, maxDelayNs: 1000)

        XCTAssertEqual(d1, 10)
        XCTAssertEqual(d2, 20)
        XCTAssertEqual(d3, 40)
    }

    func testRetryDelayHonorsMaxCap() {
        let d = BLEProtocol.retryDelay(attempt: 10, baseDelayNs: 10, maxDelayNs: 120)
        XCTAssertEqual(d, 120)
    }

    func testJitteredDelayBounds() {
        let base: UInt64 = 100
        let minDelay = BLEProtocol.jitteredDelay(delayNs: base, jitterPercent: 0.2, randomUnit: 0)
        let maxDelay = BLEProtocol.jitteredDelay(delayNs: base, jitterPercent: 0.2, randomUnit: 1)

        XCTAssertEqual(minDelay, 80)
        XCTAssertEqual(maxDelay, 120)
    }

    func testJitteredDelayNoJitterReturnsBase() {
        let base: UInt64 = 250
        let d = BLEProtocol.jitteredDelay(delayNs: base, jitterPercent: 0, randomUnit: 0.7)
        XCTAssertEqual(d, base)
    }

    func testAdaptiveJitterIncreasesOnTimeout() {
        let next = BLEProtocol.nextJitterAfterTimeout(
            current: 0.2,
            minPercent: 0.05,
            maxPercent: 0.5,
            stepUpPercent: 0.1
        )
        XCTAssertEqual(next, 0.3, accuracy: 0.0001)
    }

    func testAdaptiveJitterDecreasesOnSuccess() {
        let next = BLEProtocol.nextJitterAfterSuccess(
            current: 0.2,
            minPercent: 0.05,
            maxPercent: 0.5,
            stepDownPercent: 0.03
        )
        XCTAssertEqual(next, 0.17, accuracy: 0.0001)
    }

    func testAdaptiveJitterRespectsBounds() {
        let up = BLEProtocol.nextJitterAfterTimeout(
            current: 0.48,
            minPercent: 0.05,
            maxPercent: 0.5,
            stepUpPercent: 0.1
        )
        let down = BLEProtocol.nextJitterAfterSuccess(
            current: 0.06,
            minPercent: 0.05,
            maxPercent: 0.5,
            stepDownPercent: 0.1
        )

        XCTAssertEqual(up, 0.5, accuracy: 0.0001)
        XCTAssertEqual(down, 0.05, accuracy: 0.0001)
    }
}
