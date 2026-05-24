import Foundation

struct SyncPayload: Codable, Hashable {
    var databaseVersion: String = "ios-swift-v1"
    var projects: [Project]
    var participants: [Participant]
    var expenses: [Expense]
    var history: [ChangeHistoryEntry]
    var syncLogs: [SyncLogEntry] = []
}

struct SyncConflict: Identifiable, Codable, Hashable {
    var id: UUID
    var entityName: String
    var entityID: UUID
    var localValue: String
    var remoteValue: String
    var localRecordVersion: Int
    var remoteRecordVersion: Int
    var localUpdatedAt: Date
    var remoteUpdatedAt: Date

    init(
        id: UUID = UUID(),
        entityName: String,
        entityID: UUID,
        localValue: String,
        remoteValue: String,
        localRecordVersion: Int,
        remoteRecordVersion: Int,
        localUpdatedAt: Date,
        remoteUpdatedAt: Date
    ) {
        self.id = id
        self.entityName = entityName
        self.entityID = entityID
        self.localValue = localValue
        self.remoteValue = remoteValue
        self.localRecordVersion = localRecordVersion
        self.remoteRecordVersion = remoteRecordVersion
        self.localUpdatedAt = localUpdatedAt
        self.remoteUpdatedAt = remoteUpdatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case entityName
        case entityID = "entityId"
        case localValue
        case remoteValue
        case localRecordVersion
        case remoteRecordVersion
        case localUpdatedAt
        case remoteUpdatedAt
    }
}

struct SyncDelta: Hashable {
    var conflicts: [SyncConflict]
}
