import XCTest
@testable import SharedFinanceApp

final class RepositoryValidationTests: XCTestCase {
    @MainActor
    func testExpenseRejectedWhenParticipantNotAttachedToProject() {
        let logger = ErrorLogger()
        let db = DatabaseManager(errorLogger: logger)
        let repo = LocalSharedFinanceRepository(databaseManager: db, errorLogger: logger)

        let project = Project(title: "Trip", details: "Team trip")
        repo.upsertProject(project)

        let unattachedParticipant = Participant(name: "NoLink")
        repo.upsertParticipant(unattachedParticipant, projectID: UUID())

        let expense = Expense(
            projectID: project.id,
            participantID: unattachedParticipant.id,
            amount: 100,
            categoryID: UUID(),
            title: "Hotel"
        )

        repo.upsertExpense(expense)

        let stored = repo.fetchExpenses(projectID: project.id)
        XCTAssertTrue(stored.isEmpty)
    }

    @MainActor
    func testImportPayloadPreservesLocalProjectLinksAndAddsRemoteExpense() throws {
        let logger = ErrorLogger()
        let db = DatabaseManager(errorLogger: logger)
        let repo = LocalSharedFinanceRepository(databaseManager: db, errorLogger: logger)

        var localProject = Project(title: "Trip", details: "Local")
        let localParticipant = Participant(name: "Alice", balanceAmount: 50, recordVersion: 3)
        let localExpense = Expense(
            projectID: localProject.id,
            participantID: localParticipant.id,
            amount: 120,
            categoryID: UUID(),
            title: "Hotel",
            recordVersion: 2
        )

        repo.upsertProject(localProject)
        repo.upsertParticipant(localParticipant, projectID: localProject.id)
        repo.upsertExpense(localExpense)

        localProject = repo.fetchProject(id: localProject.id) ?? localProject

        let remoteParticipant = Participant(name: "Bob", contributionAmount: 30, recordVersion: 1)
        let remoteExpense = Expense(
            projectID: localProject.id,
            participantID: remoteParticipant.id,
            amount: 80,
            categoryID: UUID(),
            title: "Taxi",
            recordVersion: 1
        )
        let staleLocalParticipant = Participant(
            id: localParticipant.id,
            name: localParticipant.name,
            createdAt: localParticipant.createdAt,
            contributionAmount: .zero,
            expenseAmount: .zero,
            balanceAmount: .zero,
            comment: "stale",
            recordVersion: 1,
            updatedAt: localParticipant.updatedAt.addingTimeInterval(-300)
        )
        let remoteProject = Project(
            id: localProject.id,
            title: "Trip Remote",
            details: "Remote",
            createdAt: localProject.createdAt,
            participantIDs: [],
            expenseIDs: [],
            status: localProject.status,
            recordVersion: localProject.recordVersion + 1,
            updatedAt: localProject.updatedAt.addingTimeInterval(60)
        )

        repo.importPayload(
            SyncPayload(
                databaseVersion: "ios-swift-v1",
                projects: [remoteProject],
                participants: [staleLocalParticipant, remoteParticipant],
                expenses: [remoteExpense],
                history: [],
                syncLogs: []
            )
        )

        let mergedProject = try XCTUnwrap(repo.fetchProject(id: localProject.id))
        let participantIDs = Set(mergedProject.participantIDs)
        let expenseIDs = Set(mergedProject.expenseIDs)
        let storedExpenses = repo.fetchExpenses(projectID: localProject.id)
        let mergedLocalParticipant = try XCTUnwrap(repo.fetchParticipant(id: localParticipant.id))

        XCTAssertTrue(participantIDs.contains(localParticipant.id))
        XCTAssertTrue(participantIDs.contains(remoteParticipant.id))
        XCTAssertTrue(expenseIDs.contains(localExpense.id))
        XCTAssertTrue(expenseIDs.contains(remoteExpense.id))
        XCTAssertTrue(storedExpenses.contains(where: { $0.id == localExpense.id }))
        XCTAssertTrue(storedExpenses.contains(where: { $0.id == remoteExpense.id }))
        XCTAssertEqual(mergedLocalParticipant.balanceAmount, 50)
        XCTAssertEqual(mergedLocalParticipant.recordVersion, localParticipant.recordVersion)
    }
}
