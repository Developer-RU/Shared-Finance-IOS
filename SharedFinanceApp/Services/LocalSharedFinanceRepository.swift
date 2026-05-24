import Foundation

final class LocalSharedFinanceRepository: SharedFinanceRepository {
    private let databaseManager: DatabaseManager
    private let errorLogger: ErrorLogger

    init(databaseManager: DatabaseManager, errorLogger: ErrorLogger) {
        self.databaseManager = databaseManager
        self.errorLogger = errorLogger
    }

    func fetchProjects() -> [Project] {
        fetchItems(table: "projects")
    }

    func fetchProject(id: UUID) -> Project? {
        fetchProjects().first { $0.id == id }
    }

    func upsertProject(_ project: Project) {
        upsertItem(project, id: project.id, table: "projects", updatedAt: project.updatedAt, version: project.recordVersion)
    }

    func deleteProject(_ project: Project) {
        do {
            let participantIDs = Set(project.participantIDs)
            let projectExpenses = fetchExpenses(projectID: project.id)

            try databaseManager.performTransaction {
                for expense in projectExpenses {
                    try deleteItemThrowing(id: expense.id, table: "expenses")
                }

                try deleteItemThrowing(id: project.id, table: "projects")

                let remainingProjects = fetchProjects()
                let remainingParticipantIDs = Set(remainingProjects.flatMap(\ .participantIDs))
                for participantID in participantIDs where !remainingParticipantIDs.contains(participantID) {
                    try deleteItemThrowing(id: participantID, table: "participants")
                }
            }
        } catch {
            errorLogger.log(error, context: "delete project cascade")
        }
    }

    func fetchParticipants(projectID: UUID?) -> [Participant] {
        let all: [Participant] = fetchItems(table: "participants")
        guard let projectID else { return all }
        let projects = fetchProjects()
        guard let project = projects.first(where: { $0.id == projectID }) else { return [] }
        return all.filter { project.participantIDs.contains($0.id) }
    }

    func fetchParticipant(id: UUID) -> Participant? {
        let all: [Participant] = fetchItems(table: "participants")
        return all.first { $0.id == id }
    }

    func upsertParticipant(_ participant: Participant, projectID: UUID) {
        upsertItem(participant, id: participant.id, table: "participants", updatedAt: participant.updatedAt, version: participant.recordVersion)
        guard var project = fetchProjects().first(where: { $0.id == projectID }) else { return }
        if !project.participantIDs.contains(participant.id) {
            project.participantIDs.append(participant.id)
            project.recordVersion += 1
            project.updatedAt = .now
            upsertProject(project)
        }
    }

    func deleteParticipant(_ participant: Participant, projectID: UUID) -> Bool {
        let allProjects = fetchProjects()
        let allExpenses = fetchExpenses(projectID: nil)
        let participantExpensesInProject = allExpenses.filter {
            $0.projectID == projectID && $0.participantID == participant.id
        }
        let participantHasExpensesAnywhere = allExpenses.contains { $0.participantID == participant.id }
        let participantReferencedByAnyProject = allProjects.contains { $0.participantIDs.contains(participant.id) }

        guard var project = allProjects.first(where: { $0.id == projectID }) else {
            guard !participantReferencedByAnyProject && !participantHasExpensesAnywhere else {
                return false
            }

            do {
                try databaseManager.performTransaction {
                    try deleteItemThrowing(id: participant.id, table: "participants")
                }
            } catch {
                errorLogger.log(error, context: "delete orphan participant")
                return false
            }

            return true
        }

        do {
            try databaseManager.performTransaction {
                for expense in participantExpensesInProject {
                    try deleteItemThrowing(id: expense.id, table: "expenses")
                    project.expenseIDs.removeAll { $0 == expense.id }
                }

                let wasLinkedToProject = project.participantIDs.contains(participant.id)
                project.participantIDs.removeAll { $0 == participant.id }
                if wasLinkedToProject || !participantExpensesInProject.isEmpty {
                    project.recordVersion += 1
                    project.updatedAt = .now
                    upsertProject(project)
                }

                let remainingProjects = fetchProjects()
                let isStillReferenced = remainingProjects.contains { $0.participantIDs.contains(participant.id) }
                if !isStillReferenced {
                    try deleteItemThrowing(id: participant.id, table: "participants")
                }
            }
        } catch {
            errorLogger.log(error, context: "delete participant cascade")
            return false
        }

        return true
    }

    func fetchExpenses(projectID: UUID?) -> [Expense] {
        let all: [Expense] = fetchItems(table: "expenses")
        guard let projectID else { return all }
        return all.filter { $0.projectID == projectID }
    }

    func upsertExpense(_ expense: Expense) {
        guard let project = fetchProject(id: expense.projectID) else {
            errorLogger.log("Rejecting expense: project does not exist")
            return
        }
        guard fetchParticipant(id: expense.participantID) != nil else {
            errorLogger.log("Rejecting expense: participant does not exist")
            return
        }
        guard project.participantIDs.contains(expense.participantID) else {
            errorLogger.log("Rejecting expense: participant is not attached to project")
            return
        }

        upsertItem(expense, id: expense.id, table: "expenses", updatedAt: expense.updatedAt, version: expense.recordVersion)
        guard var project = fetchProjects().first(where: { $0.id == expense.projectID }) else { return }
        if !project.expenseIDs.contains(expense.id) {
            project.expenseIDs.append(expense.id)
            project.recordVersion += 1
            project.updatedAt = .now
            upsertProject(project)
        }
    }

    func deleteExpense(_ expense: Expense) {
        deleteItem(id: expense.id, table: "expenses")
        guard var project = fetchProject(id: expense.projectID) else { return }
        project.expenseIDs.removeAll { $0 == expense.id }
        project.recordVersion += 1
        project.updatedAt = .now
        upsertProject(project)
    }

    func fetchHistory() -> [ChangeHistoryEntry] {
        fetchItems(table: "history").sorted { $0.date > $1.date }
    }

    func appendHistory(_ entry: ChangeHistoryEntry) {
        upsertItem(entry, id: entry.id, table: "history", updatedAt: entry.date, version: entry.recordVersion)
    }

    func fetchSyncLogs() -> [SyncLogEntry] {
        fetchItems(table: "sync_logs").sorted { $0.date > $1.date }
    }

    func appendSyncLog(_ entry: SyncLogEntry) {
        upsertItem(entry, id: entry.id, table: "sync_logs", updatedAt: entry.date, version: 1)
    }

    func exportPayload() -> SyncPayload {
        SyncPayload(
            databaseVersion: "ios-swift-v1",
            projects: fetchProjects(),
            participants: fetchParticipants(projectID: nil),
            expenses: fetchExpenses(projectID: nil),
            history: fetchHistory(),
            syncLogs: fetchSyncLogs()
        )
    }

    func importPayload(_ payload: SyncPayload) {
        do {
            try databaseManager.performTransaction {
                let mergedParticipants = mergeRecords(
                    local: fetchParticipants(projectID: nil),
                    remote: payload.participants,
                    id: \Participant.id,
                    version: \Participant.recordVersion,
                    updatedAt: \Participant.updatedAt
                )
                let mergedExpenses = mergeRecords(
                    local: fetchExpenses(projectID: nil),
                    remote: payload.expenses,
                    id: \Expense.id,
                    version: \Expense.recordVersion,
                    updatedAt: \Expense.updatedAt
                )
                let mergedProjects = mergeProjects(
                    local: fetchProjects(),
                    remote: payload.projects,
                    mergedExpenses: mergedExpenses
                )
                let mergedHistory = mergeRecords(
                    local: fetchHistory(),
                    remote: payload.history,
                    id: \ChangeHistoryEntry.id,
                    version: \ChangeHistoryEntry.recordVersion,
                    updatedAt: \ChangeHistoryEntry.date
                )
                let mergedSyncLogs = mergeRecords(
                    local: fetchSyncLogs(),
                    remote: payload.syncLogs,
                    id: \SyncLogEntry.id,
                    version: { _ in 1 },
                    updatedAt: \SyncLogEntry.date
                )

                mergedProjects.forEach { upsertItem($0, id: $0.id, table: "projects", updatedAt: $0.updatedAt, version: $0.recordVersion) }
                mergedParticipants.forEach { upsertItem($0, id: $0.id, table: "participants", updatedAt: $0.updatedAt, version: $0.recordVersion) }
                mergedExpenses.forEach { upsertExpense($0) }
                mergedHistory.forEach { appendHistory($0) }
                mergedSyncLogs.forEach { appendSyncLog($0) }
            }
        } catch {
            errorLogger.log(error, context: "import payload transaction")
        }
    }

    private func mergeProjects(local: [Project], remote: [Project], mergedExpenses: [Expense]) -> [Project] {
        var merged = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for remoteProject in remote {
            guard let localProject = merged[remoteProject.id] else {
                merged[remoteProject.id] = enrichProjectAssociations(remoteProject, mergedExpenses: mergedExpenses)
                continue
            }

            let preferRemoteScalars = shouldPreferRemote(
                local: localProject,
                remote: remoteProject,
                version: \Project.recordVersion,
                updatedAt: \Project.updatedAt
            )
            merged[remoteProject.id] = mergeProject(
                local: localProject,
                remote: remoteProject,
                preferRemoteScalars: preferRemoteScalars,
                mergedExpenses: mergedExpenses
            )
        }

        return merged.values
            .map { enrichProjectAssociations($0, mergedExpenses: mergedExpenses) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func mergeProject(local: Project, remote: Project, preferRemoteScalars: Bool, mergedExpenses: [Expense]) -> Project {
        let base = preferRemoteScalars ? remote : local
        let projectExpenses = mergedExpenses.filter { $0.projectID == local.id }
        return Project(
            id: base.id,
            title: base.title,
            details: base.details,
            createdAt: base.createdAt,
            participantIDs: Array(Set(local.participantIDs + remote.participantIDs + projectExpenses.map(\.participantID))),
            expenseIDs: Array(Set(local.expenseIDs + remote.expenseIDs + projectExpenses.map(\.id))),
            status: base.status,
            recordVersion: max(local.recordVersion, remote.recordVersion),
            updatedAt: max(local.updatedAt, remote.updatedAt)
        )
    }

    private func enrichProjectAssociations(_ project: Project, mergedExpenses: [Expense]) -> Project {
        let projectExpenses = mergedExpenses.filter { $0.projectID == project.id }
        return Project(
            id: project.id,
            title: project.title,
            details: project.details,
            createdAt: project.createdAt,
            participantIDs: Array(Set(project.participantIDs + projectExpenses.map(\.participantID))),
            expenseIDs: Array(Set(project.expenseIDs + projectExpenses.map(\.id))),
            status: project.status,
            recordVersion: project.recordVersion,
            updatedAt: project.updatedAt
        )
    }

    private func mergeRecords<T>(
        local: [T],
        remote: [T],
        id: KeyPath<T, UUID>,
        version: KeyPath<T, Int>,
        updatedAt: KeyPath<T, Date>
    ) -> [T] {
        mergeRecords(local: local, remote: remote, id: id, version: { $0[keyPath: version] }, updatedAt: { $0[keyPath: updatedAt] })
    }

    private func mergeRecords<T>(
        local: [T],
        remote: [T],
        id: KeyPath<T, UUID>,
        version: (T) -> Int,
        updatedAt: (T) -> Date
    ) -> [T] {
        var merged = Dictionary(uniqueKeysWithValues: local.map { ($0[keyPath: id], $0) })
        for remoteItem in remote {
            let itemID = remoteItem[keyPath: id]
            guard let localItem = merged[itemID] else {
                merged[itemID] = remoteItem
                continue
            }
            if shouldPreferRemote(local: localItem, remote: remoteItem, version: version, updatedAt: updatedAt) {
                merged[itemID] = remoteItem
            }
        }
        return Array(merged.values)
    }

    private func shouldPreferRemote<T>(local: T, remote: T, version: (T) -> Int, updatedAt: (T) -> Date) -> Bool {
        let localVersion = version(local)
        let remoteVersion = version(remote)
        if remoteVersion != localVersion {
            return remoteVersion > localVersion
        }
        return updatedAt(remote) > updatedAt(local)
    }

    private func upsertItem<T: Encodable>(_ item: T, id: UUID, table: String, updatedAt: Date, version: Int) {
        do {
            let data = try JSONEncoder.pretty.encode(item)
            let json = String(decoding: data, as: UTF8.self)
            try databaseManager.execute(
                sql: "INSERT OR REPLACE INTO \(table) (id, payload, updated_at, version) VALUES (?, ?, ?, ?);",
                bindings: [id.uuidString, json, updatedAt.ISO8601Format(), "\(version)"]
            )
        } catch {
            errorLogger.log(error, context: "upsert \(table)")
        }
    }

    private func deleteItem(id: UUID, table: String) {
        do {
            try deleteItemThrowing(id: id, table: table)
        } catch {
            errorLogger.log(error, context: "delete \(table)")
        }
    }

    private func deleteItemThrowing(id: UUID, table: String) throws {
        do {
            try databaseManager.execute(sql: "DELETE FROM \(table) WHERE id = ?;", bindings: [id.uuidString])
        }
    }

    private func fetchItems<T: Decodable>(table: String) -> [T] {
        do {
            let rows = try databaseManager.query(sql: "SELECT payload FROM \(table);")
            return rows.compactMap { row in
                guard let payload = row["payload"], let data = payload.data(using: .utf8) else { return nil }
                return try? JSONDecoder.shared.decode(T.self, from: data)
            }
        } catch {
            errorLogger.log(error, context: "fetch \(table)")
            return []
        }
    }
}
