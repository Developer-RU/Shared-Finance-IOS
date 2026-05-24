import Foundation

protocol SharedFinanceRepository {
    func fetchProjects() -> [Project]
    func fetchProject(id: UUID) -> Project?
    func upsertProject(_ project: Project)
    func deleteProject(_ project: Project)

    func fetchParticipants(projectID: UUID?) -> [Participant]
    func fetchParticipant(id: UUID) -> Participant?
    func upsertParticipant(_ participant: Participant, projectID: UUID)
    func deleteParticipant(_ participant: Participant, projectID: UUID)

    func fetchExpenses(projectID: UUID?) -> [Expense]
    func upsertExpense(_ expense: Expense)
    func deleteExpense(_ expense: Expense)

    func fetchHistory() -> [ChangeHistoryEntry]
    func appendHistory(_ entry: ChangeHistoryEntry)

    func fetchSyncLogs() -> [SyncLogEntry]
    func appendSyncLog(_ entry: SyncLogEntry)

    func fetchConflictResolutionLogs() -> [ConflictResolutionLogEntry]
    func appendConflictResolutionLog(_ entry: ConflictResolutionLogEntry)

    func exportPayload() -> SyncPayload
    func importPayload(_ payload: SyncPayload)
}
