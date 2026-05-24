import XCTest
@testable import SharedFinanceApp

final class ProjectsViewModelTests: XCTestCase {
    @MainActor
    func testProjectBalanceSumsParticipantBalancesMinusExpenses() {
        let logger = ErrorLogger()
        let db = DatabaseManager(errorLogger: logger)
        let repo = LocalSharedFinanceRepository(databaseManager: db, errorLogger: logger)
        let viewModel = ProjectsViewModel(repository: repo, errorLogger: logger)

        let project = Project(title: "Trip", details: "Weekend trip")
        repo.upsertProject(project)

        let participant = Participant(name: "Alex", contributionAmount: 150)
        repo.upsertParticipant(participant, projectID: project.id)

        let expense = Expense(
            projectID: project.id,
            participantID: participant.id,
            amount: 40,
            categoryID: UUID(),
            title: "Taxi"
        )
        repo.upsertExpense(expense)

        XCTAssertEqual(viewModel.balance(for: project), 110)
    }
}
