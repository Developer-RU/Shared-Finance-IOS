import Foundation

struct ChangeHistoryEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var operationType: HistoryOperationType
    var actorName: String
    var date: Date
    var description: String
    var recordVersion: Int

    init(
        id: UUID = UUID(),
        operationType: HistoryOperationType,
        actorName: String,
        date: Date = .now,
        description: String,
        recordVersion: Int
    ) {
        self.id = id
        self.operationType = operationType
        self.actorName = actorName
        self.date = date
        self.description = description
        self.recordVersion = recordVersion
    }
}

enum HistoryOperationType: String, Codable {
    case create
    case update
    case delete
    case sync

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()
        switch rawValue {
        case "create":
            self = .create
        case "update":
            self = .update
        case "delete":
            self = .delete
        case "sync":
            self = .sync
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported history operation type: \(rawValue)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .create:
            try container.encode("CREATE")
        case .update:
            try container.encode("UPDATE")
        case .delete:
            try container.encode("DELETE")
        case .sync:
            try container.encode("SYNC")
        }
    }
}

struct SyncLogEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var deviceName: String
    var result: SyncResult
    var changedRecordsCount: Int
    var bleLogicalPacketCount: Int?
    var bleRetryCount: Int?
    var bleTimeoutCount: Int?
    var bleAverageRetryDelayNs: UInt64?
    var bleMaxRetryDelayNs: UInt64?
    var bleJitterPercent: Double?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        deviceName: String,
        result: SyncResult,
        changedRecordsCount: Int,
        bleLogicalPacketCount: Int? = nil,
        bleRetryCount: Int? = nil,
        bleTimeoutCount: Int? = nil,
        bleAverageRetryDelayNs: UInt64? = nil,
        bleMaxRetryDelayNs: UInt64? = nil,
        bleJitterPercent: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.deviceName = deviceName
        self.result = result
        self.changedRecordsCount = changedRecordsCount
        self.bleLogicalPacketCount = bleLogicalPacketCount
        self.bleRetryCount = bleRetryCount
        self.bleTimeoutCount = bleTimeoutCount
        self.bleAverageRetryDelayNs = bleAverageRetryDelayNs
        self.bleMaxRetryDelayNs = bleMaxRetryDelayNs
        self.bleJitterPercent = bleJitterPercent
    }
}

enum SyncResult: String, Codable {
    case success
    case conflict
    case failed

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()
        switch rawValue {
        case "success":
            self = .success
        case "conflict":
            self = .conflict
        case "failed":
            self = .failed
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported sync result: \(rawValue)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .success:
            try container.encode("SUCCESS")
        case .conflict:
            try container.encode("CONFLICT")
        case .failed:
            try container.encode("FAILED")
        }
    }

    var localizedKey: String {
        switch self {
        case .success: return "sync_result_success"
        case .conflict: return "sync_result_conflict"
        case .failed: return "sync_result_failed"
        }
    }
}

struct ConflictResolutionLogEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var entityName: String
    var entityID: UUID
    var localValue: String
    var remoteValue: String
    var decision: ConflictResolutionDecision
    var decisionSource: ConflictDecisionSource
    var isApplied: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case entityName
        case entityID = "entityId"
        case localValue
        case remoteValue
        case decision
        case decisionSource
        case isApplied
    }
}

enum ConflictResolutionDecision: String, Codable, CaseIterable {
    case acceptRemote
    case keepLocal

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()
        switch rawValue {
        case "acceptremote", "accept_remote":
            self = .acceptRemote
        case "keeplocal", "keep_local":
            self = .keepLocal
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported conflict decision: \(rawValue)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .acceptRemote:
            try container.encode("ACCEPT_REMOTE")
        case .keepLocal:
            try container.encode("KEEP_LOCAL")
        }
    }
}

enum ConflictDecisionSource: String, Codable {
    case manual
    case automatic

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()
        switch rawValue {
        case "manual":
            self = .manual
        case "automatic":
            self = .automatic
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported conflict decision source: \(rawValue)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .manual:
            try container.encode("MANUAL")
        case .automatic:
            try container.encode("AUTOMATIC")
        }
    }
}
