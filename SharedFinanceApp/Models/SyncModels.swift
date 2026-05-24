import Foundation

struct SyncPayload: Codable, Hashable {
    var databaseVersion: String = "ios-swift-v1"
    var projects: [Project]
    var participants: [Participant]
    var expenses: [Expense]
    var history: [ChangeHistoryEntry]
    var syncLogs: [SyncLogEntry] = []
}
