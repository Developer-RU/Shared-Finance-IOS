import XCTest
@testable import SharedFinanceApp

final class SharedFinanceAppTests: XCTestCase {
    func testExample() {
        let state = AppState()
        XCTAssertEqual(state.selectedTab, .projects)
    }

    @MainActor
    func testBalanceDeleteParticipantAlsoUsesExpenseProjectLinks() throws {
        let logger = ErrorLogger()
        let db = DatabaseManager(errorLogger: logger)
        let repo = LocalSharedFinanceRepository(databaseManager: db, errorLogger: logger)

        var project = Project(title: "Trip", details: "Team trip")
        let participant = Participant(name: "Alex", contributionAmount: 100)
        let expense = Expense(
            projectID: project.id,
            participantID: participant.id,
            amount: 100,
            categoryID: UUID(),
            title: "Hotel"
        )

        repo.upsertProject(project)
        repo.upsertParticipant(participant, projectID: project.id)
        repo.upsertExpense(expense)

        project = try XCTUnwrap(repo.fetchProject(id: project.id))
        project.participantIDs.removeAll { $0 == participant.id }
        repo.upsertProject(project)

        let viewModel = BalanceViewModel(repository: repo, errorLogger: logger)
        viewModel.load(projectID: nil)
        viewModel.deleteParticipant(participantID: participant.id)

        XCTAssertNil(repo.fetchParticipant(id: participant.id))
        XCTAssertTrue(repo.fetchExpenses(projectID: project.id).isEmpty)
    }

    @MainActor
    func testParticipantsDeleteDoesNotAppendHistoryWhenDeleteFails() throws {
        let logger = ErrorLogger()
        let db = DatabaseManager(errorLogger: logger)
        let repo = LocalSharedFinanceRepository(databaseManager: db, errorLogger: logger)

        let project = Project(title: "Trip", details: "Team trip")
        let participant = Participant(name: "Alex", contributionAmount: 40)
        repo.upsertProject(project)
        repo.upsertParticipant(participant, projectID: project.id)

        let viewModel = ParticipantsViewModel(repository: repo, errorLogger: logger)
        let historyCountBeforeDelete = repo.fetchHistory().count

        viewModel.delete(participant: participant, projectID: UUID())

        XCTAssertEqual(repo.fetchHistory().count, historyCountBeforeDelete)
        XCTAssertNotNil(repo.fetchParticipant(id: participant.id))
    }

    @MainActor
    func testBalanceDeleteWithoutRelatedProjectsDeletesOrphanParticipant() throws {
        let logger = ErrorLogger()
        let db = DatabaseManager(errorLogger: logger)
        let repo = LocalSharedFinanceRepository(databaseManager: db, errorLogger: logger)

        let unattachedParticipant = Participant(name: "Orphan", contributionAmount: 20)
        repo.upsertParticipant(unattachedParticipant, projectID: UUID())

        let viewModel = BalanceViewModel(repository: repo, errorLogger: logger)
        viewModel.load(projectID: nil)
        let historyCountBeforeDelete = repo.fetchHistory().count

        viewModel.deleteParticipant(participantID: unattachedParticipant.id)

        XCTAssertEqual(repo.fetchHistory().count, historyCountBeforeDelete + 1)
        XCTAssertNil(repo.fetchParticipant(id: unattachedParticipant.id))
    }
}
