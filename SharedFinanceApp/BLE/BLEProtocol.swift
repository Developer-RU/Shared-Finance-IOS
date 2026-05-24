import Foundation

struct BLETransferTelemetry: Codable, Hashable {
    var logicalPacketCount: Int
    var retryCount: Int
    var timeoutCount: Int
    var averageRetryDelayNs: UInt64
    var maxRetryDelayNs: UInt64
    var jitterPercent: Double
}

enum BLETransferError: Error, LocalizedError {
    case deviceNotConnected
    case ackTimeout(Int)
    case invalidPacket
    case responseTimeout

    var errorDescription: String? {
        switch self {
        case .deviceNotConnected:
            return "BLE device is not connected"
        case .ackTimeout(let index):
            return "BLE ACK timeout at chunk \(index)"
        case .invalidPacket:
            return "BLE invalid packet"
        case .responseTimeout:
            return "BLE response timeout"
        }
    }
}

enum BLEProtocol {
    struct Config {
        let serviceUUID: String
        let transferCharacteristicUUID: String
        let notifyCharacteristicUUID: String
        let chunkSize: Int
        let ackTimeoutNs: UInt64
        let responseTimeoutNs: UInt64
        let maxAckRetries: Int
        let ackRetryBaseDelayNs: UInt64
        let ackRetryMaxDelayNs: UInt64
        let ackRetryJitterPercent: Double
        let ackAdaptiveJitterMinPercent: Double
        let ackAdaptiveJitterMaxPercent: Double
        let ackAdaptiveJitterStepUpPercent: Double
        let ackAdaptiveJitterStepDownPercent: Double

        static let `default` = Config(
            serviceUUID: "0000A1F0-0000-1000-8000-00805F9B34FB",
            transferCharacteristicUUID: "0000A1F1-0000-1000-8000-00805F9B34FB",
            notifyCharacteristicUUID: "0000A1F2-0000-1000-8000-00805F9B34FB",
            chunkSize: 180,
            ackTimeoutNs: 2_500_000_000,
            responseTimeoutNs: 15_000_000_000,
            maxAckRetries: 2,
            ackRetryBaseDelayNs: 40_000_000,
            ackRetryMaxDelayNs: 400_000_000,
            ackRetryJitterPercent: 0.2,
            ackAdaptiveJitterMinPercent: 0.05,
            ackAdaptiveJitterMaxPercent: 0.5,
            ackAdaptiveJitterStepUpPercent: 0.05,
            ackAdaptiveJitterStepDownPercent: 0.02
        )
    }

    static let controlStartIndex: UInt32 = UInt32.max - 1
    static let controlEndIndex: UInt32 = UInt32.max

    enum PacketType: UInt8 {
        case start = 1
        case chunk = 2
        case end = 3
        case ack = 4
    }

    struct Packet {
        let type: PacketType
        let index: UInt32
        let payload: Data
    }

    static func encode(type: PacketType, index: UInt32, payload: Data = Data()) -> Data {
        var data = Data()
        data.append(type.rawValue)
        data.append(contentsOf: withUnsafeBytes(of: index.bigEndian, Array.init))
        data.append(payload)
        return data
    }

    static func decode(_ data: Data) -> Packet? {
        guard data.count >= 5 else { return nil }
        guard let type = PacketType(rawValue: data[0]) else { return nil }

        let indexBytes = data.subdata(in: 1..<5)
        let index = indexBytes.withUnsafeBytes { raw -> UInt32 in
            let value = raw.load(as: UInt32.self)
            return UInt32(bigEndian: value)
        }
        let payload = data.count > 5 ? data.subdata(in: 5..<data.count) : Data()
        return Packet(type: type, index: index, payload: payload)
    }

    static func chunk(_ data: Data, size: Int = Config.default.chunkSize) -> [Data] {
        guard size > 0 else { return [] }
        guard !data.isEmpty else { return [] }

        var chunks: [Data] = []
        var offset = 0
        while offset < data.count {
            let end = min(offset + size, data.count)
            chunks.append(data.subdata(in: offset..<end))
            offset = end
        }
        return chunks
    }

    static func totalAttempts(maxRetries: Int) -> Int {
        max(1, maxRetries + 1)
    }

    static func retryDelay(attempt: Int, baseDelayNs: UInt64, maxDelayNs: UInt64) -> UInt64 {
        guard attempt > 0 else { return 0 }
        guard baseDelayNs > 0 else { return 0 }
        let exponent = min(attempt - 1, 20)
        let factor = UInt64(1 << exponent)
        let scaled = baseDelayNs &* factor
        if maxDelayNs == 0 {
            return scaled
        }
        return min(scaled, maxDelayNs)
    }

    static func jitteredDelay(delayNs: UInt64, jitterPercent: Double, randomUnit: Double) -> UInt64 {
        guard delayNs > 0 else { return 0 }
        guard jitterPercent > 0 else { return delayNs }

        let clampedRandom = min(max(randomUnit, 0), 1)
        let clampedJitter = min(max(jitterPercent, 0), 1)
        let minFactor = 1.0 - clampedJitter
        let maxFactor = 1.0 + clampedJitter
        let factor = minFactor + (maxFactor - minFactor) * clampedRandom

        let adjusted = Double(delayNs) * factor
        return UInt64(max(0, adjusted.rounded()))
    }

    static func telemetry(
        logicalPacketCount: Int,
        retryCount: Int,
        timeoutCount: Int,
        totalRetryDelayNs: UInt64,
        maxRetryDelayNs: UInt64,
        jitterPercent: Double
    ) -> BLETransferTelemetry {
        let averageDelay: UInt64
        if retryCount > 0 {
            averageDelay = totalRetryDelayNs / UInt64(retryCount)
        } else {
            averageDelay = 0
        }

        return BLETransferTelemetry(
            logicalPacketCount: logicalPacketCount,
            retryCount: retryCount,
            timeoutCount: timeoutCount,
            averageRetryDelayNs: averageDelay,
            maxRetryDelayNs: maxRetryDelayNs,
            jitterPercent: jitterPercent
        )
    }

    static func nextJitterAfterTimeout(current: Double, minPercent: Double, maxPercent: Double, stepUpPercent: Double) -> Double {
        let clampedMin = min(max(minPercent, 0), 1)
        let clampedMax = min(max(maxPercent, clampedMin), 1)
        let stepped = current + max(stepUpPercent, 0)
        return min(max(stepped, clampedMin), clampedMax)
    }

    static func nextJitterAfterSuccess(current: Double, minPercent: Double, maxPercent: Double, stepDownPercent: Double) -> Double {
        let clampedMin = min(max(minPercent, 0), 1)
        let clampedMax = min(max(maxPercent, clampedMin), 1)
        let stepped = current - max(stepDownPercent, 0)
        return min(max(stepped, clampedMin), clampedMax)
    }
}
